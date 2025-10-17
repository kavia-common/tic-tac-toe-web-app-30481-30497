#!/usr/bin/env bash
# activate venv and load .env.local
export WORKON_HOME="$WORKSPACE/.venv"
. "$WORKSPACE"/.venv/bin/activate
[ -f "$WORKSPACE/.env.local" ] && set -a && . "$WORKSPACE/.env.local" && set +a
