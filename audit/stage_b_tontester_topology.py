#!/usr/bin/env python3
"""Локальный Stage B runner для `clean target + attacker-only full-node`.

Скрипт НЕ патчит target checkout и НЕ форсирует DownloadState напрямую. Он строит
контролируемую tontester-сеть в два этапа:

1. donor-этап: clean donor validators продвигают masterchain, patched attacker sync'ается
   как обычный full-node, runner автоматически извлекает реальные BlockIdExt через tonlib;
2. target-этап: donor validators останавливаются, stopped clean target DB seed'ится реальным
   PersistentStateDescription, после чего clean target стартует и может выбрать attacker как
   единственный reachable persistent-state source.

Если clean target не вошёл в persistent-state download path, runner печатает BLOCKER и
сохраняет все логи для разбора причины.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import csv
import logging
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
TONTESTER_SRC = REPO_ROOT / "test" / "tontester" / "src"
MASTERCHAIN_SHARD = -(1 << 63)

LOG = logging.getLogger("stage_b_tontester_topology")


def read_rss_kb(pid: int) -> tuple[int | None, int | None, int | None]:
    status = Path(f"/proc/{pid}/status")
    if not status.exists():
        return None, None, None
    values: dict[str, int] = {}
    for line in status.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0] in {"VmRSS:", "VmHWM:", "VmSize:"}:
            values[parts[0]] = int(parts[1])
    return values.get("VmRSS:"), values.get("VmHWM:"), values.get("VmSize:")


async def sample_rss(pid: int, out: Path, stop: asyncio.Event) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["unix_ts", "pid", "VmRSS_kB", "VmHWM_kB", "VmSize_kB"])
        while not stop.is_set() and Path(f"/proc/{pid}").exists():
            vmrss, vmhwm, vmsize = read_rss_kb(pid)
            writer.writerow([int(time.time()), pid, vmrss, vmhwm, vmsize])
            f.flush()
            try:
                await asyncio.wait_for(stop.wait(), timeout=1.0)
            except TimeoutError:
                pass


def process_pid(node: Any) -> int:
    # tontester хранит asyncio.subprocess.Process в приватном поле базового Network.Node.
    proc = getattr(node, "_Node__process")
    if proc is None or proc.pid is None:
        raise RuntimeError(f"узел {node.name} ещё не запущен")
    return proc.pid


def tail_text(path: Path, max_bytes: int = 4 * 1024 * 1024) -> str:
    if not path.exists():
        return ""
    data = path.read_bytes()
    return data[-max_bytes:].decode("utf-8", errors="replace")


def count_attacker_slices(log: str) -> int:
    return len(re.findall(r"TON_POC_MALICIOUS_STATE downloadPersistentStateSliceV2 slice=", log))


def _bytes_hex(value: Any) -> str:
    """Вернуть hex для hash-поля tonlib: bytes или base64 string."""
    if isinstance(value, bytes):
        return value.hex()
    if isinstance(value, str):
        return base64.b64decode(value).hex()
    raise TypeError(f"неподдерживаемый hash type: {type(value)!r}")


def block_id_ext_to_cpp(block: Any) -> str:
    """Формат BlockIdExt, который принимает ton::BlockIdExt::from_str()."""
    shard_unsigned = int(block.shard) & ((1 << 64) - 1)
    return (
        f"({int(block.workchain)},{shard_unsigned:016x},{int(block.seqno)}):"
        f"{_bytes_hex(block.root_hash)}:{_bytes_hex(block.file_hash)}"
    )


async def wait_node_mc_block(node: Any, seqno: int, timeout: float) -> Any:
    """Дождаться, пока конкретный full-node liteserver увидит masterchain >= seqno."""
    deadline = time.monotonic() + timeout
    client = await node.tonlib_client()
    last_info = None
    while time.monotonic() < deadline:
        try:
            info = await client.get_masterchain_info()
            last_info = info
            if info.last is not None and int(info.last.seqno) >= seqno:
                return info
        except Exception as e:  # noqa: BLE001 - runner обязан сохранить blocker, а не падать без контекста
            LOG.debug("ожидание mc seqno=%s на %s: %r", seqno, node.name, e)
        await asyncio.sleep(0.5)
    raise TimeoutError(f"узел {node.name} не достиг masterchain seqno>={seqno}; last={last_info}")


async def extract_seed_blocks(donor_node: Any, min_confirmed_seqno: int, confirmation_gap: int) -> tuple[str, str, int, int]:
    """Автоматически выбрать реальные mc/shard BlockIdExt из donor/localnet через tonlib."""
    if confirmation_gap <= 16:
        raise ValueError("confirmation_gap должен быть >16, иначе product-path gate не проходит")

    client = await donor_node.tonlib_client()
    mc_info = await client.get_masterchain_info()
    if mc_info.last is None:
        raise RuntimeError("donor tonlib не вернул last masterchain block")
    min_confirmed = int(mc_info.last.seqno)
    if min_confirmed < min_confirmed_seqno:
        raise RuntimeError(f"donor mc seqno={min_confirmed}, ожидалось >= {min_confirmed_seqno}")

    seed_mc_seqno = min_confirmed - confirmation_gap
    if seed_mc_seqno < 1:
        raise RuntimeError(
            f"нельзя выбрать seed mc block: min_confirmed={min_confirmed}, confirmation_gap={confirmation_gap}"
        )

    mc_block = await client.lookup_block(workchain=-1, shard=MASTERCHAIN_SHARD, seqno=seed_mc_seqno)
    shards = await client.get_shards(mc_block)
    shard_list = [s for s in getattr(shards, "shards") if int(s.workchain) != -1]
    if not shard_list:
        raise RuntimeError(f"у donor mc block seqno={seed_mc_seqno} нет shard/basechain blocks")

    shard_block = next((s for s in shard_list if int(s.workchain) == 0), shard_list[0])
    if int(mc_block.seqno) + 16 >= min_confirmed:
        raise RuntimeError(
            "выбранный mc_block не проходит gate: "
            f"{int(mc_block.seqno)} + 16 >= min_confirmed {min_confirmed}"
        )

    return block_id_ext_to_cpp(mc_block), block_id_ext_to_cpp(shard_block), int(mc_block.seqno), min_confirmed


def run_seed_tool(args: argparse.Namespace, target: Any, mc_block: str, shard_block: str) -> Path:
    if args.seed_tool is None:
        raise RuntimeError("для DB-seed нужен --seed-tool")
    state_db = target._directory / "state"
    state_db.mkdir(parents=True, exist_ok=True)
    seed_cmd = [
        str(args.seed_tool),
        "--state-db",
        str(state_db),
        "--mc-block",
        mc_block,
        "--shard-block",
        shard_block,
        "--start-time",
        args.seed_start_time,
        "--end-time",
        args.seed_end_time,
        "--split-depth",
        args.seed_split_depth,
    ]
    LOG.info("seeding stopped target DB: %s", " ".join(seed_cmd))
    seed_log = args.workdir / "seed_persistent_state_description.log"
    with seed_log.open("w", encoding="utf-8") as f:
        subprocess.run(seed_cmd, check=True, stdout=f, stderr=subprocess.STDOUT)
    LOG.info("seed log=%s", seed_log)
    return seed_log


async def main() -> int:
    parser = argparse.ArgumentParser(description="Stage B tontester topology runner для state-download PoC")
    parser.add_argument("--target-build", required=True, type=Path, help="build dir clean target checkout, например build-target")
    parser.add_argument("--attacker-build", required=True, type=Path, help="build dir attacker checkout с patch, например build-attacker")
    parser.add_argument("--target-source", default=REPO_ROOT, type=Path, help="source dir clean target checkout")
    parser.add_argument("--attacker-source", default=REPO_ROOT, type=Path, help="source dir attacker checkout")
    parser.add_argument("--workdir", default=REPO_ROOT / "audit" / "stage_b_tontester_workdir", type=Path)
    parser.add_argument("--runtime-seconds", default=300, type=int, help="сколько секунд держать target после старта")
    parser.add_argument("--declared-state-size", default=1 << 40, type=int, help="TON_POC_MALICIOUS_STATE_SIZE")
    parser.add_argument("--keep-workdir", action="store_true", help="не удалять старый workdir перед стартом")
    parser.add_argument("--seed-tool", type=Path, help="путь к seed-persistent-state-description из отдельного tool checkout")
    parser.add_argument("--seed-mc-block", help="опционально: готовый реальный BlockIdExt masterchain блока")
    parser.add_argument("--seed-shard-block", help="опционально: готовый реальный BlockIdExt shard/basechain блока")
    parser.add_argument("--seed-start-time", default="1", help="start_time для seeded PersistentStateDescription")
    parser.add_argument("--seed-end-time", default="4102444800", help="end_time для seeded PersistentStateDescription")
    parser.add_argument("--seed-split-depth", default="0", help="split_depth для seeded shard block")
    parser.add_argument("--auto-prepare-seed", action="store_true", help="поднять donor/localnet и автоматически извлечь реальные BlockIdExt")
    parser.add_argument("--donor-validator-count", default=2, type=int, help="сколько clean donor validators запускать")
    parser.add_argument("--donor-mc-seqno", default=24, type=int, help="до какого masterchain seqno продвинуть donor/localnet")
    parser.add_argument("--seed-confirmation-gap", default=17, type=int, help="gap для проверки mc_seqno + 16 < min_confirmed")
    parser.add_argument("--attacker-sync-timeout", default=120, type=int, help="timeout ожидания sync attacker до donor mc seqno")
    args = parser.parse_args()

    sys.path.insert(0, str(TONTESTER_SRC))
    try:
        from tontester.install import Install
        from tontester.network import Network, StartOptions
    except ModuleNotFoundError as e:
        print("Не найдены Python-зависимости tontester.", file=sys.stderr)
        print("Установите их командой: python3 -m pip install -e test/tontester", file=sys.stderr)
        raise SystemExit(2) from e

    logging.basicConfig(level=logging.INFO, format="[%(levelname)s][%(asctime)s][%(name)s] %(message)s")

    if args.auto_prepare_seed and (args.seed_mc_block or args.seed_shard_block):
        raise RuntimeError("используйте либо --auto-prepare-seed, либо ручные --seed-mc-block/--seed-shard-block, но не вместе")
    if args.auto_prepare_seed and args.seed_tool is None:
        raise RuntimeError("--auto-prepare-seed требует --seed-tool")
    if args.donor_validator_count < 1:
        raise RuntimeError("--donor-validator-count должен быть >=1")

    target_install = Install(args.target_build, args.target_source)
    attacker_install = Install(args.attacker_build, args.attacker_source)

    if not args.keep_workdir:
        shutil.rmtree(args.workdir, ignore_errors=True)
    args.workdir.mkdir(parents=True, exist_ok=True)

    LOG.info("workdir=%s", args.workdir)
    LOG.info("target_build=%s", target_install.build_dir)
    LOG.info("attacker_build=%s", attacker_install.build_dir)

    stop_rss = asyncio.Event()
    rss_task: asyncio.Task[None] | None = None
    seed_log: Path | None = None
    extracted_mc_seqno: int | None = None
    extracted_min_confirmed: int | None = None

    async with Network(target_install, args.workdir) as network:
        dht = network.create_dht_node()
        network.config.shard_validators = max(1, args.donor_validator_count)

        donors = []
        for _ in range(args.donor_validator_count):
            donor = network.create_full_node()
            donor.make_initial_validator()
            donor.announce_to(dht)
            donors.append(donor)

        target = network.create_full_node()
        target.announce_to(dht)

        attacker = network.create_full_node()
        attacker.announce_to(dht)

        LOG.info("donor fullnode adnl=%s", [d.fullnode_key.id.hex() for d in donors])
        LOG.info("target fullnode adnl=%s", target.fullnode_key.id.hex())
        LOG.info("attacker fullnode adnl=%s", attacker.fullnode_key.id.hex())

        attacker_options = StartOptions(
            install=attacker_install,
            env={
                "TON_POC_MALICIOUS_STATE": "1",
                "TON_POC_MALICIOUS_STATE_SIZE": str(args.declared_state_size),
            },
            verbosity=4,
            console_verbosity=4,
        )
        donor_options = StartOptions(verbosity=4, console_verbosity=4)
        target_options = StartOptions(verbosity=4, console_verbosity=4)

        async with asyncio.TaskGroup() as tg:
            tg.create_task(dht.run())
            for donor in donors:
                tg.create_task(donor.run(donor_options))
            tg.create_task(attacker.run(attacker_options))

        attacker_pid = process_pid(attacker)
        LOG.info("attacker pid=%s log=%s", attacker_pid, attacker.log_path)

        mc_block = args.seed_mc_block
        shard_block = args.seed_shard_block
        if args.auto_prepare_seed:
            await network.wait_mc_block(seqno=args.donor_mc_seqno)
            attacker_info = await wait_node_mc_block(attacker, args.donor_mc_seqno, args.attacker_sync_timeout)
            LOG.info("attacker synced to mc seqno=%s before target start", attacker_info.last.seqno if attacker_info.last else None)
            mc_block, shard_block, extracted_mc_seqno, extracted_min_confirmed = await extract_seed_blocks(
                donors[0], args.donor_mc_seqno, args.seed_confirmation_gap
            )
            env_path = args.workdir / "stage_b_seed_blocks.env"
            env_path.write_text(
                f"STAGE_B_MC_BLOCK={mc_block}\n"
                f"STAGE_B_SHARD_BLOCK={shard_block}\n"
                f"STAGE_B_SEED_MC_SEQNO={extracted_mc_seqno}\n"
                f"STAGE_B_MIN_CONFIRMED_MC_SEQNO={extracted_min_confirmed}\n",
                encoding="utf-8",
            )
            LOG.info("auto seed blocks saved to %s", env_path)
        elif not (mc_block and shard_block):
            LOG.warning("DB-seed не задан; свежая tontester-сеть, вероятно, завершится BLOCKER без persistent-state path")
        elif not args.seed_tool:
            raise RuntimeError("для ручных seed block args нужен --seed-tool")

        # После donor/extractor этапа honest donors останавливаются: attacker остаётся единственным
        # reachable full-node, который успел синхронизироваться и может быть выбран как download_from_.
        for donor in donors:
            await donor.stop()

        if mc_block and shard_block:
            seed_log = run_seed_tool(args, target, mc_block, shard_block)

        async with asyncio.TaskGroup() as tg:
            tg.create_task(target.run(target_options))

        target_pid = process_pid(target)
        LOG.info("target pid=%s log=%s", target_pid, target.log_path)

        rss_path = args.workdir / "target_rss.log"
        rss_task = asyncio.create_task(sample_rss(target_pid, rss_path, stop_rss))

        try:
            await wait_node_mc_block(target, max(3, args.donor_mc_seqno), timeout=120)
            LOG.info("target достиг donor mc seqno; ждём runtime window %ss", args.runtime_seconds)
        except Exception as e:  # noqa: BLE001 - audit runner must preserve logs and report blocker
            LOG.warning("target не достиг ожидаемого mc seqno: %r", e)

        await asyncio.sleep(args.runtime_seconds)

        target_log = tail_text(target.log_path)
        attacker_log = tail_text(attacker.log_path)
        downloading_from_attacker = (
            "downloading state" in target_log and attacker.fullnode_key.id.hex()[:16].lower() in target_log.lower()
        )
        any_downloading_state = "downloading state" in target_log
        slice_count = count_attacker_slices(attacker_log)

        stop_rss.set()
        if rss_task is not None:
            await rss_task

        summary_path = args.workdir / "stage_b_summary.txt"
        with summary_path.open("w", encoding="utf-8") as f:
            f.write(f"target_pid={target_pid}\n")
            f.write(f"attacker_pid={attacker_pid}\n")
            f.write(f"donor_adnls={[d.fullnode_key.id.hex() for d in donors]}\n")
            f.write(f"target_adnl={target.fullnode_key.id.hex()}\n")
            f.write(f"attacker_adnl={attacker.fullnode_key.id.hex()}\n")
            f.write(f"target_log={target.log_path}\n")
            f.write(f"attacker_log={attacker.log_path}\n")
            f.write(f"target_rss={rss_path}\n")
            f.write(f"seed_tool={args.seed_tool}\n")
            f.write(f"seed_log={seed_log}\n")
            f.write(f"auto_prepare_seed={args.auto_prepare_seed}\n")
            f.write(f"seed_mc_block={mc_block}\n")
            f.write(f"seed_shard_block={shard_block}\n")
            f.write(f"seed_mc_seqno={extracted_mc_seqno}\n")
            f.write(f"min_confirmed_mc_seqno={extracted_min_confirmed}\n")
            f.write(f"any_downloading_state={any_downloading_state}\n")
            f.write(f"downloading_from_attacker_heuristic={downloading_from_attacker}\n")
            f.write(f"attacker_slice_count={slice_count}\n")

        if any_downloading_state and slice_count > 0:
            print("PASS_CANDIDATE: persistent-state download был замечен, attacker отдавал malicious slices.")
            print(f"Проверьте вручную target log: {target.log_path}")
            print(f"Проверьте attacker log: {attacker.log_path}")
            print(f"RSS log: {rss_path}")
            print(f"Summary: {summary_path}")
            return 0

        print("BLOCKER: topology запущена, но product-path persistent-state download от attacker не подтверждён.")
        print("Проверьте seed block env, target downloader logs, attacker slice logs и target_rss.log.")
        print(f"Логи сохранены: target={target.log_path} attacker={attacker.log_path} rss={rss_path}")
        print(f"Summary: {summary_path}")
        return 2


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
