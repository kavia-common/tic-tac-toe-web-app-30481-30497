#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-web-app-30481-30497/backend"
cd "$WORKSPACE"
[ -f "$WORKSPACE/.workspace_env.sh" ] && . "$WORKSPACE/.workspace_env.sh"
PY="$WORKSPACE"/.venv/bin/python
LOG="$WORKSPACE/django_run.log"
# safe idempotent fix: ensure 'include' is imported in project/urls.py when webapp is referenced
PYTHONCODE=$(cat <<'PY'
from pathlib import Path
p=Path('project/urls.py')
if not p.exists():
    print('noop')
else:
    s=p.read_text()
    changed=False
    # if 'include' is needed (webapp.urls referenced) but not imported, add the import
    # Be conservative: only add when 'webapp.urls' appears and 'include' token is not present in file
    if 'webapp.urls' in s and 'include' not in s:
        if 'from django.urls import' in s:
            # insert include into existing import list (first occurrence)
            s=s.replace('from django.urls import', 'from django.urls import include,',1)
            changed=True
        else:
            # add a simple import line preserving existing content
            s='from django.urls import include, path\n'+s
            changed=True
    if changed:
        p.write_text(s)
    print('ok')
PY
)
# run the python edit using workspace venv python (ignore failures to avoid blocking if venv missing)
echo "$PYTHONCODE" | "$PY" - >/dev/null 2>&1 || true
# apply migrations, capturing output to LOG
"$PY" manage.py migrate --noinput >"$LOG" 2>&1 || (tail -n 200 "$LOG" >&2; exit 2)
# start server with autoreload disabled, write logs to LOG
"$PY" manage.py runserver 0.0.0.0:8000 --noreload >"$LOG" 2>&1 &
PID=$!
trap 'kill ${PID} >/dev/null 2>&1 || true; sleep 1; if ps -p ${PID} >/dev/null 2>&1; then kill -9 ${PID} >/dev/null 2>&1 || true; fi' EXIT
# poll readiness
RETRIES=20
SLEEP=1
OK=0
HTTP_CODE=""
for i in $(seq 1 $RETRIES); do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/ || true)
  [ "$HTTP_CODE" = "200" ] && OK=1 && break
  sleep $SLEEP
done
if [ "$OK" -ne 1 ]; then
  echo "validation failed: root did not return 200; last code=${HTTP_CODE:-none}" >&2
  echo "---- server log (tail) ----" >&2
  tail -n 200 "$LOG" >&2 || true
  if ps -p "$PID" -o args= | grep -q "$WORKSPACE"; then kill -9 "$PID" || true; fi
  exit 2
fi
# clean shutdown
kill "$PID" >/dev/null 2>&1 || true
wait "$PID" 2>/dev/null || true
echo "validation ok: root returned 200" > "$WORKSPACE/.validation_ok"
date -u > "$WORKSPACE/.setup_validation_stamp"
