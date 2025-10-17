#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-web-app-30481-30497/backend"
cd "$WORKSPACE"
# load workspace env if present (activates venv and loads .env.local)
[ -f "$WORKSPACE/.workspace_env.sh" ] && . "$WORKSPACE/.workspace_env.sh"
PY="$WORKSPACE"/.venv/bin/python
# Ensure PY exists, else try system python (fail fast if not available)
if [ ! -x "$PY" ]; then
  if command -v python3 >/dev/null 2>&1; then
    PY=$(command -v python3)
  else
    echo "No python interpreter found" >&2
    exit 1
  fi
fi
# create a non-destructive sample test only if tests.py missing
if [ ! -f "$WORKSPACE/webapp/tests.py" ]; then
  mkdir -p "$WORKSPACE/webapp"
  cat > "$WORKSPACE/webapp/tests.py" <<'PY'
from django.test import Client, TestCase

class RootTest(TestCase):
    def test_root(self):
        c = Client()
        resp = c.get('/')
        self.assertEqual(resp.status_code, 200)
PY
fi
# makemigrations and migrate (makemigrations may return non-zero if no changes; tolerate)
"$PY" manage.py makemigrations --noinput || true
"$PY" manage.py migrate --noinput
# run tests (show failures)
"$PY" manage.py test --verbosity=1
# stamp
date -u > "$WORKSPACE/.setup_test_stamp"
