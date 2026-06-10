#!/usr/bin/env python3
"""
Stage A PoC harness for the TON DownloadState persistent-state slice accumulation candidate.

This intentionally does NOT patch or exercise the vulnerable validator binary. It reproduces the
memory-retention semantics of validator/net/download-state.cpp::DownloadState::got_block_state_part:
  last_part = data.size() < requested_size
  sum_ += data.size()
  parts_.push_back(std::move(data))
  if (!last_part) request next slice at offset=sum_

Use this as a fast, deterministic Stage A artifact before building the Stage B malicious full-node
product-path reproduction described in audit/TON_STATE_DOWNLOAD_POC.md.
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
import time
from dataclasses import asdict, dataclass

PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")


@dataclass
class Sample:
    elapsed_s: float
    slice_no: int
    requested_size: int
    response_size: int
    retained_chunks: int
    sum_bytes: int
    declared_total_size: int
    current_rss_bytes: int
    malicious_bytes_sent: int
    last_part: bool
    status: str


def current_rss_bytes() -> int:
    """Return current RSS for this process, preferring /proc for exact Linux values."""
    try:
        with open("/proc/self/status", "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    # VmRSS:   12345 kB
                    return int(line.split()[1]) * 1024
    except OSError:
        pass
    return 0


def format_bytes(value: int) -> str:
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    v = float(value)
    for unit in units:
        if v < 1024.0 or unit == units[-1]:
            return f"{v:.2f} {unit}"
        v /= 1024.0
    return f"{value} B"


def make_committed_chunk(size: int, seq: int) -> bytearray:
    """Allocate and touch memory so RSS growth is visible, then retain it like BufferSlice in parts_."""
    chunk = bytearray(size)
    marker = seq & 0xFF
    # Touch every page to force physical commitment instead of lazy virtual allocation.
    for offset in range(0, size, PAGE_SIZE):
        chunk[offset] = marker
    if size:
        chunk[-1] = marker
    return chunk


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Stage A harness for unbounded DownloadState persistent-state slice accumulation"
    )
    parser.add_argument("--slices", type=int, default=64, help="number of full-size malicious slice responses")
    parser.add_argument("--slice-size", type=int, default=1 << 21, help="requested_size/response_size per slice")
    parser.add_argument(
        "--declared-total-size",
        type=int,
        default=4 << 20,
        help="peer-advertised total_size_; intentionally smaller than accumulated bytes by default",
    )
    parser.add_argument("--csv", default="audit/poc_download_state_accumulation.csv", help="CSV metrics output path")
    parser.add_argument(
        "--rss-stop-mib",
        type=int,
        default=0,
        help="optional safety stop if current RSS exceeds this MiB; 0 disables",
    )
    parser.add_argument("--log-every", type=int, default=1, help="print downloader-style log every N slices")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.slices <= 0 or args.slice_size <= 0:
        print("slices and slice-size must be positive", file=sys.stderr)
        return 2

    os.makedirs(os.path.dirname(args.csv) or ".", exist_ok=True)

    # Mirrors DownloadState private fields used by got_block_state_part().
    parts: list[bytearray] = []
    sum_bytes = 0
    malicious_bytes_sent = 0
    requested_size = args.slice_size
    start = time.monotonic()
    samples: list[Sample] = []
    status = "healthy"

    print("[stage-a] starting DownloadState accumulation harness")
    print(f"[stage-a] declared_total_size={format_bytes(args.declared_total_size)}")
    print(f"[stage-a] malicious response size per slice={format_bytes(requested_size)}")
    print(f"[stage-a] target process pid={os.getpid()} (RSS sampled from /proc/self/status)")

    for slice_no in range(1, args.slices + 1):
        # Malicious peer behavior: return exactly requested_size bytes every time, so last_part is false.
        data = make_committed_chunk(requested_size, slice_no)
        response_size = len(data)
        malicious_bytes_sent += response_size

        # Exact vulnerable retention semantics from DownloadState::got_block_state_part().
        last_part = response_size < requested_size
        sum_bytes += response_size
        parts.append(data)

        rss = current_rss_bytes()
        elapsed = time.monotonic() - start
        if args.rss_stop_mib and rss > args.rss_stop_mib * 1024 * 1024:
            status = "rss_safety_stop"

        sample = Sample(
            elapsed_s=elapsed,
            slice_no=slice_no,
            requested_size=requested_size,
            response_size=response_size,
            retained_chunks=len(parts),
            sum_bytes=sum_bytes,
            declared_total_size=args.declared_total_size,
            current_rss_bytes=rss,
            malicious_bytes_sent=malicious_bytes_sent,
            last_part=last_part,
            status=status,
        )
        samples.append(sample)

        if slice_no % args.log_every == 0 or status != "healthy":
            pct = (sum_bytes / args.declared_total_size * 100.0) if args.declared_total_size else 0.0
            print(
                "downloading state poc-block : "
                f"{format_bytes(sum_bytes)}/{format_bytes(args.declared_total_size)} "
                f"({pct:.2f}%, rss={format_bytes(rss)}, retained_chunks={len(parts)}, "
                f"last_part={str(last_part).lower()})"
            )

        if last_part:
            status = "unexpected_short_read_abort"
            break
        if status != "healthy":
            break

    with open(args.csv, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(asdict(samples[0]).keys()) if samples else [])
        writer.writeheader()
        for sample in samples:
            writer.writerow(asdict(sample))

    final = samples[-1]
    pass_condition = (
        final.retained_chunks == final.slice_no
        and final.sum_bytes == final.malicious_bytes_sent
        and final.sum_bytes > args.declared_total_size
        and not final.last_part
        and final.status in {"healthy", "rss_safety_stop"}
    )
    summary = {
        "stage": "A",
        "target_pid": os.getpid(),
        "csv": args.csv,
        "slices_completed": final.slice_no,
        "retained_chunks": final.retained_chunks,
        "sum_bytes": final.sum_bytes,
        "declared_total_size": final.declared_total_size,
        "malicious_bytes_sent": final.malicious_bytes_sent,
        "current_rss_bytes": final.current_rss_bytes,
        "last_part": final.last_part,
        "status": final.status,
        "pass": pass_condition,
    }
    print("[stage-a] summary:")
    print(json.dumps(summary, indent=2, sort_keys=True))
    if pass_condition:
        print("[stage-a] PASS: full-size chunks were retained beyond declared total_size without a cap/abort.")
        return 0
    print("[stage-a] FAIL: harness did not reproduce the expected accumulation semantics.", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
