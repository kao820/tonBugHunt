# CODEX_LAST_STATUS

STATUS: local-script-prepared / no-runtime-executed

Candidate: CN-ARCHIVE-01

## Why runtime was not executed

The requested task was file-only. No build, tests, dependency installation, or PoC execution was performed. The local script is a safe skeleton that performs repository/tool/submodule preflight checks, prepares bounded log and metrics directories, and documents topology-specific TODO commands without executing them.

## Created files

- `audit/run_cn_archive_01_local.sh` — safe local PoC skeleton for CN-ARCHIVE-01.
- `audit/CODEX_LAST_STATUS.md` — status note for this package.

## How user should run

From the repository root on a machine prepared for local TON experimentation:

```bash
CN_ARCHIVE_WORKDIR="${HOME}/ton-cn-archive-01-local" \
CN_ARCHIVE_MAX_BYTES=268435456 \
CN_ARCHIVE_MAX_SECONDS=180 \
bash audit/run_cn_archive_01_local.sh
```

The script does not execute the exploit or start topology processes. After the preflight succeeds, fill in the printed TODO placeholders with topology-specific target and attacker commands in an isolated filesystem, disposable VM, quota-limited directory, sparse throwaway image, or tmpfs.

## Expected PASS evidence

Do not report CN-ARCHIVE-01 as PASS/report-ready unless bounded runtime evidence includes all of the following:

1. Target log evidence containing `Importing archive from net`.
2. Target or attacker log evidence containing `downloading archive slice from attacker`.
3. Evidence of repeated full-size archive slices from the malicious full-node neighbour.
4. `du`/`df` metrics showing `db_root/tmp` growth during repeated slices while respecting `CN_ARCHIVE_MAX_BYTES` and `CN_ARCHIVE_MAX_SECONDS`.

## Expected BLOCKER/CLOSE evidence

Treat the candidate as blocked or close it if runtime evidence shows any of the following:

- Required tools or submodules, especially `third-party/openssl`, are missing.
- The tested topology cannot route the malicious full-node neighbour to the archive-slice download path.
- The target rejects, truncates, rate-limits, or otherwise bounds the malicious archive slices before temp-file growth.
- `db_root/tmp` remains bounded under the configured byte and time limits.
