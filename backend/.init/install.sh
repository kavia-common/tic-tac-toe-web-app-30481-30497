#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/kavia/workspace/code-generation/tic-tac-toe-web-app-30481-30497/backend"
cd "$WORKSPACE"
# check python version
PY_SYS=$(python3 -V 2>&1 | awk '{print $2}')
PY_MAJOR=$(echo "$PY_SYS" | cut -d. -f1)
PY_MINOR=$(echo "$PY_SYS" | cut -d. -f2)
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 8 ]; }; then
  echo "error: python3 >=3.8 required for Django (found $PY_SYS)" >&2; exit 3
fi
# create venv idempotently
python3 -m venv .venv
PY="$WORKSPACE"/.venv/bin/python
# ensure pip/setuptools updated and capture logs
$PY -m pip install --upgrade pip setuptools wheel > "$WORKSPACE/pip_install.log" 2>&1
# create workspace-local .env.local with dev SECRET_KEY (600)
if [ ! -f "$WORKSPACE/.env.local" ]; then
  PYKEY=$($PY - <<'PY'
import secrets
print('dev-' + secrets.token_hex(24))
PY
)
  cat > "$WORKSPACE/.env.local" <<EOF
# Development-only environment file (do not commit)
# SECRET_KEY is for development only
SECRET_KEY=$PYKEY
EOF
  chmod 600 "$WORKSPACE/.env.local"
fi
# ensure .gitignore contains .env.local
if [ -f "$WORKSPACE/.gitignore" ]; then
  grep -qxF ".env.local" "$WORKSPACE/.gitignore" || echo ".env.local" >> "$WORKSPACE/.gitignore"
fi
# create workspace wrapper to activate venv and load .env.local
WRAPPER="$WORKSPACE/.workspace_env.sh"
cat > "$WRAPPER" <<'EOF'
# workspace venv activation wrapper (source this in automation to use venv)
if [ -f "./.venv/bin/activate" ]; then . "./.venv/bin/activate"; fi
# load workspace-local .env.local into environment if present
if [ -f "./.env.local" ]; then set -a; . "./.env.local"; set +a; fi
EOF
chmod 644 "$WRAPPER"
# Optionally write a global profile only if APPROVED_GLOBAL=1 is set (opt-in)
if [ "${APPROVED_GLOBAL:-0}" = "1" ]; then
  PROFILE=/etc/profile.d/django_dev.sh
  TMP=$(mktemp)
  cat > "$TMP" <<'EOF'
# exported by automated dev setup (opt-in): sets DJANGO_SETTINGS_MODULE if you opt in
# WARNING: this exports a project-specific value globally; only enable intentionally
export DJANGO_SETTINGS_MODULE=project.settings
EOF
  sudo mv "$TMP" "$PROFILE" && sudo chmod 644 "$PROFILE"
fi
# verify venv python
$PY --version > /dev/null
# minimal setup log
date -u > "$WORKSPACE/.setup_env_stamp"
