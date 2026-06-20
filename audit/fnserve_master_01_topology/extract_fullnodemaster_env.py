#!/usr/bin/env python3
"""Extract FNSERVE-MASTER-01 env from a local/private validator-engine config.

This helper is intentionally conservative: it never starts processes and never
sends traffic. It succeeds only when an existing local config already contains a
fullnodemaster and the caller supplies or the config/logs expose all PoC target
variables needed by audit/run_fnserve_master_01_local.sh.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

PUB_ED25519_PREFIX = bytes.fromhex("c6b41348")
BLOCK_RE = re.compile(r"\(-?\d+,[0-9a-fA-F]{16},\d+\):[0-9a-fA-F]{64}:[0-9a-fA-F]{64}")


def shell_quote(value: str) -> str:
    return "'" + value.replace("'", "'\\''") + "'"


def public_key_tl_bytes(raw: str) -> bytes:
    # Tontester/engine JSON stores PublicKey as base64-encoded boxed TL bytes.
    data = base64.b64decode(raw)
    if len(data) >= 36 and data[:4] == PUB_ED25519_PREFIX:
        return data
    if len(data) == 32:
        return PUB_ED25519_PREFIX + data
    raise ValueError("unsupported PublicKey encoding in config")


def short_id_from_public_key(raw: str) -> str:
    return hashlib.sha256(public_key_tl_bytes(raw)).digest().hex()


def int256_to_hex(value) -> str:
    if isinstance(value, str):
        try:
            data = base64.b64decode(value)
            if len(data) == 32:
                return data.hex()
            if len(data) >= 36:
                return hashlib.sha256(data).digest().hex()
        except Exception:
            pass
        s = value.lower().removeprefix("0x")
        if len(s) == 64 and all(c in "0123456789abcdef" for c in s):
            return s
    raise ValueError(f"unsupported int256 encoding: {value!r}")


def find_pid_for_config(config: Path) -> str:
    try:
        out = subprocess.check_output(["ps", "-eo", "pid=,args="], text=True)
    except Exception:
        return ""
    cfg = str(config)
    for line in out.splitlines():
        if "validator-engine" in line and cfg in line:
            return line.strip().split(maxsplit=1)[0]
    return ""


def first_block_from_logs(workdir: Path, want_zero: bool) -> str:
    for path in sorted(workdir.rglob("*.log")) + sorted(workdir.rglob("log")):
        try:
            text = path.read_text(errors="ignore")
        except Exception:
            continue
        for match in BLOCK_RE.findall(text):
            seqno = int(match.split(",", 2)[2].split(")", 1)[0])
            if want_zero and seqno == 0:
                return match
            if not want_zero and seqno > 0:
                return match
    return ""


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--config", required=True)
    p.add_argument("--output-env", required=True)
    p.add_argument("--workdir", required=True)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--validator-engine", default="")
    p.add_argument("--target-pid", default="")
    p.add_argument("--zero-state-block", default="")
    p.add_argument("--block-id", default="")
    args = p.parse_args()

    config_path = Path(args.config).resolve()
    workdir = Path(args.workdir).resolve()
    output = Path(args.output_env).resolve()
    if args.host not in {"127.0.0.1", "localhost", "::1"} and not args.host.startswith("127."):
        print("FORMAT FNSERVE_TOPOLOGY_BLOCKED")
        print(f"exact reason: refusing non-local full-node-master host {args.host}")
        print("exact missing repo capability: local/private fullNodeMaster endpoint")
        print("whether this parks or closes FNSERVE-MASTER-01: parked")
        return 2

    cfg = json.loads(config_path.read_text())
    masters = cfg.get("fullnodemasters") or []
    if not masters:
        print("FORMAT FNSERVE_TOPOLOGY_BLOCKED")
        print(f"exact reason: {config_path} has no engine.validator.fullNodeMaster entries")
        print("exact missing repo capability: configured local fullnodemaster in supplied config")
        print("whether this parks or closes FNSERVE-MASTER-01: parked")
        return 2

    adnl_by_short: dict[str, str] = {}
    for entry in cfg.get("adnl", []) or []:
        raw = entry.get("id")
        if isinstance(raw, str):
            try:
                adnl_by_short[short_id_from_public_key(raw)] = public_key_tl_bytes(raw).hex()
            except Exception:
                continue

    master = masters[0]
    port = str(master.get("port") or "")
    master_short = int256_to_hex(master.get("adnl"))
    pub_hex = adnl_by_short.get(master_short, os.environ.get("FNSERVE_MASTER_PUBKEY_TL_HEX", ""))

    zero = args.zero_state_block or os.environ.get("FNSERVE_ZERO_STATE_BLOCK", "") or first_block_from_logs(workdir, True)
    block = args.block_id or os.environ.get("FNSERVE_BLOCK_ID", "") or first_block_from_logs(workdir, False)
    pid = args.target_pid or os.environ.get("FNSERVE_TARGET_PID", "") or find_pid_for_config(config_path)
    ve = args.validator_engine or os.environ.get("FNSERVE_VALIDATOR_ENGINE", "")

    missing = []
    for key, value in {
        "FNSERVE_MASTER_PORT": port,
        "FNSERVE_MASTER_PUBKEY_TL_HEX": pub_hex,
        "FNSERVE_ZERO_STATE_BLOCK": zero,
        "FNSERVE_BLOCK_ID": block,
        "FNSERVE_TARGET_PID": pid,
        "FNSERVE_VALIDATOR_ENGINE": ve,
    }.items():
        if not value:
            missing.append(key)
    if missing:
        print("FORMAT FNSERVE_TOPOLOGY_BLOCKED")
        print("exact reason: local config contains fullnodemaster but required run variables are missing: " + ", ".join(missing))
        print("exact missing repo capability: automatic derivation of all FNSERVE run variables from supplied local config/logs")
        print("whether this parks or closes FNSERVE-MASTER-01: parked")
        return 2

    values = {
        "FNSERVE_CONFIG": str(config_path),
        "FNSERVE_MASTER_HOST": "127.0.0.1",
        "FNSERVE_MASTER_PORT": port,
        "FNSERVE_MASTER_PUBKEY_TL_HEX": pub_hex,
        "FNSERVE_ZERO_STATE_BLOCK": zero,
        "FNSERVE_BLOCK_ID": block,
        "FNSERVE_TARGET_PID": pid,
        "FNSERVE_VALIDATOR_ENGINE": ve,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as f:
        f.write("# Generated by audit/fnserve_master_01_topology/extract_fullnodemaster_env.py\n")
        for key, value in values.items():
            f.write(f"export {key}={shell_quote(value)}\n")
    print("FORMAT FNSERVE_TOPOLOGY_READY")
    print(f"env_file={output}")
    for key in values:
        print(f"{key}={values[key]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
