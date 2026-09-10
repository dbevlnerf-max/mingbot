#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${1:-$HOME/mingbot}"
BRANCH="${2:-main}"
OLD_COMMIT="$(git -C "$APP_DIR" rev-parse HEAD)"
echo "이전 커밋: $OLD_COMMIT"
git -C "$APP_DIR" fetch origin "$BRANCH"
git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"
"$APP_DIR/.venv/bin/python" -m py_compile "$APP_DIR/bot.py"
sudo systemctl restart simbangbot
sleep 2
sudo systemctl --no-pager --full status simbangbot
