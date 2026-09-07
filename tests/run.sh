#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bash tests/test_apply_check.sh
bash tests/test_rollback.sh
python3 tests/test_keyd_bundle.py
python3 tests/test_shell_merge.py
bash tests/test_wwan_latency_switcher.sh

printf '%s\n' "ok"
