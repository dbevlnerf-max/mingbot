#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/dbevlnerf-max/mingbot.git}"
BRANCH="${2:-main}"
RUN_USER="${SUDO_USER:-$USER}"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
APP_DIR="${RUN_HOME}/mingbot"
ENV_DIR="/etc/simbangbot"
ENV_FILE="${ENV_DIR}/simbangbot.env"
DATA_DIR="/var/lib/simbangbot"
SERVICE_FILE="/etc/systemd/system/simbangbot.service"

if [[ $EUID -ne 0 ]]; then
  echo "sudo로 실행해주세요: sudo bash setup_server.sh"
  exit 1
fi

echo "[1/9] Ubuntu/Debian 패키지 설치"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y git python3 python3-venv python3-pip ffmpeg libopus0

echo "[2/9] Git 저장소 준비: $APP_DIR"
if [[ -d "${APP_DIR}/.git" ]]; then
  sudo -u "$RUN_USER" git -C "$APP_DIR" fetch origin "$BRANCH"
  sudo -u "$RUN_USER" git -C "$APP_DIR" checkout "$BRANCH"
  sudo -u "$RUN_USER" git -C "$APP_DIR" pull --ff-only origin "$BRANCH"
else
  rm -rf "$APP_DIR"
  sudo -u "$RUN_USER" git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR"
fi

echo "[3/9] Python venv / requirements"
if [[ ! -d "${APP_DIR}/.venv" ]]; then
  sudo -u "$RUN_USER" python3 -m venv "${APP_DIR}/.venv"
fi
sudo -u "$RUN_USER" "${APP_DIR}/.venv/bin/python" -m pip install --upgrade pip wheel
sudo -u "$RUN_USER" "${APP_DIR}/.venv/bin/pip" install -r "${APP_DIR}/requirements.txt"

echo "[4/9] 환경/DB 폴더"
install -d -m 0750 -o "$RUN_USER" -g "$RUN_USER" "$ENV_DIR"
install -d -m 0750 -o "$RUN_USER" -g "$RUN_USER" "$DATA_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  cp "${APP_DIR}/.env.example" "$ENV_FILE"
  chown "$RUN_USER:$RUN_USER" "$ENV_FILE"
  chmod 0600 "$ENV_FILE"
fi

echo "[5/9] systemd 서비스 등록"
sed \
  -e "s|__RUN_USER__|${RUN_USER}|g" \
  -e "s|__APP_DIR__|${APP_DIR}|g" \
  -e "s|__ENV_FILE__|${ENV_FILE}|g" \
  "${APP_DIR}/simbangbot.service.template" > "$SERVICE_FILE"
systemctl daemon-reload
systemctl enable simbangbot.service

echo "[6/9] 권한 정리"
chown -R "$RUN_USER:$RUN_USER" "$APP_DIR" "$DATA_DIR" "$ENV_DIR"
chmod 0750 "$ENV_DIR" "$DATA_DIR"
chmod 0600 "$ENV_FILE"

echo "[7/9] 구성 검사"
"${APP_DIR}/.venv/bin/python" -m py_compile "${APP_DIR}/bot.py"
command -v ffmpeg >/dev/null

echo "[8/9] 시작 가능 여부"
if grep -q 'PUT_YOUR_DISCORD_BOT_TOKEN_HERE' "$ENV_FILE"; then
  echo "환경파일에 Discord 토큰이 아직 없습니다. 자동 시작을 보류합니다."
  echo "파일: $ENV_FILE"
else
  systemctl restart simbangbot.service
  sleep 3
  systemctl --no-pager --full status simbangbot.service || true
fi

echo "[9/9] 완료"
echo "APP:     $APP_DIR"
echo "ENV:     $ENV_FILE"
echo "DB:      $DATA_DIR/simbangbot.db"
echo "GOOGLE:  $ENV_DIR/google-service-account.json"
echo "SERVICE: simbangbot.service"
