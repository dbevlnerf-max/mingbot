#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sudo bash setup_server.sh <GIT_REPO_URL> [BRANCH]

REPO_URL="${1:-}"
BRANCH="${2:-main}"

if [[ -z "$REPO_URL" ]]; then
  echo "사용법: sudo bash setup_server.sh <GIT_REPO_URL> [BRANCH]"
  exit 1
fi

RUN_USER="${SUDO_USER:-$USER}"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
APP_DIR="${RUN_HOME}/simbangbot"
ENV_DIR="/etc/simbangbot"
ENV_FILE="${ENV_DIR}/simbangbot.env"
DATA_DIR="/var/lib/simbangbot"
SERVICE_FILE="/etc/systemd/system/simbangbot.service"

echo "[1/9] 패키지 설치"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 python3-venv python3-pip ffmpeg

echo "[2/9] 앱 폴더 준비"
if [[ -d "${APP_DIR}/.git" ]]; then
  sudo -u "$RUN_USER" git -C "$APP_DIR" fetch origin "$BRANCH"
  sudo -u "$RUN_USER" git -C "$APP_DIR" checkout "$BRANCH"
  sudo -u "$RUN_USER" git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
else
  rm -rf "$APP_DIR"
  sudo -u "$RUN_USER" git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

echo "[3/9] Python venv 구성"
sudo -u "$RUN_USER" python3 -m venv "${APP_DIR}/.venv"
sudo -u "$RUN_USER" "${APP_DIR}/.venv/bin/python" -m pip install --upgrade pip wheel
sudo -u "$RUN_USER" "${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo "[4/9] 환경설정/DB 디렉터리 준비"
install -d -m 0750 -o "$RUN_USER" -g "$RUN_USER" "$ENV_DIR"
install -d -m 0750 -o "$RUN_USER" -g "$RUN_USER" "$DATA_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "${APP_DIR}/.env.example" "$ENV_FILE"
  chown "$RUN_USER:$RUN_USER" "$ENV_FILE"
  chmod 0600 "$ENV_FILE"
  echo
  echo "!!! 중요 !!!"
  echo "$ENV_FILE 파일이 생성되었습니다."
  echo "DISCORD_TOKEN 등 실제 값을 입력한 뒤 서비스를 시작해야 합니다."
fi

echo "[5/9] systemd 서비스 생성"
sed \
  -e "s|__RUN_USER__|${RUN_USER}|g" \
  -e "s|__APP_DIR__|${APP_DIR}|g" \
  -e "s|__ENV_FILE__|${ENV_FILE}|g" \
  "${APP_DIR}/simbangbot.service.template" > "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable simbangbot.service

echo "[6/9] 파일 소유권 확인"
chown -R "$RUN_USER:$RUN_USER" "$APP_DIR" "$DATA_DIR" "$ENV_DIR"

echo "[7/9] 설정 파일 상태"
if grep -q "여기에_봇_토큰" "$ENV_FILE"; then
  echo "아직 토큰이 입력되지 않아 자동 시작하지 않습니다."
  echo "수정: sudo nano $ENV_FILE"
else
  echo "[8/9] 심방봇 시작"
  systemctl restart simbangbot.service
  sleep 3
  systemctl --no-pager --full status simbangbot.service || true
fi

echo "[9/9] 완료"
echo "앱:     $APP_DIR"
echo "환경:   $ENV_FILE"
echo "DB:     $DATA_DIR/simbangbot.db"
echo "서비스: simbangbot.service"
echo
echo "자주 쓰는 명령:"
echo "  sudo systemctl status simbangbot"
echo "  sudo systemctl restart simbangbot"
echo "  sudo systemctl stop simbangbot"
echo "  sudo journalctl -u simbangbot -f"
