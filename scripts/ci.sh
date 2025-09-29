#!/usr/bin/env bash
set -euo pipefail
python -m compileall -q .
python - <<PY
import importlib
for m in ["api.main","shared.db","pyhole.dns_monitor","pyalloc.main","pyalloc.allocator"]:
    importlib.import_module(m)
print("imports ok")
PY
(uvicorn api.main:app --host 127.0.0.1 --port 8090 --log-level error & echo $! > /tmp/api.pid)
sleep 2
curl -fsS http://127.0.0.1:8090/health >/dev/null
kill "$(cat /tmp/api.pid)" || true
echo "ci ok"
