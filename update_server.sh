#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${1:-$HOME/simbangbot}"
BRANCH="${2:-main}"

echo "[1/5] 현재 커밋 저장"
OLD_COMMIT="$(git -C "$APP_DIR" rev-parse HEAD)"
echo "$OLD_COMMIT"

echo "[2/5] Git Pull"
git -C "$APP_DIR" fetch origin "$BRANCH"
git -C "$APP_DIR" pull --ff-only origin "$BRANCH"

echo "[3/5] requirements 갱신"
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements.txt"

echo "[4/5] 서비스 재시작"
sudo systemctl restart simbangbot

echo "[5/5] 상태"
sudo systemctl --no-pager --full status simbangbot
