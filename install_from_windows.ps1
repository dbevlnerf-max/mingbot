param(
    [Parameter(Mandatory=$true)] [string]$Server,
    [string]$RepoUrl = "https://github.com/dbevlnerf-max/mingbot.git",
    [string]$Branch = "main",
    [string]$LocalBotFolder = ""
)

$ErrorActionPreference = "Stop"
Write-Host "=== 밍봇 서버 이전 도우미 ===" -ForegroundColor Cyan

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { throw "Windows OpenSSH ssh 명령을 찾지 못했습니다." }
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) { throw "Windows OpenSSH scp 명령을 찾지 못했습니다." }

if (-not $LocalBotFolder) {
    $LocalBotFolder = Read-Host "현재 로컬 밍봇 폴더 경로 (bot.py/.env/simbangbot.db가 있는 폴더)"
}
$LocalBotFolder = (Resolve-Path $LocalBotFolder).Path
$EnvFile = Join-Path $LocalBotFolder ".env"
$DbFile = Join-Path $LocalBotFolder "simbangbot.db"
$GoogleFile = Join-Path $LocalBotFolder "google-service-account.json"

if (-not (Test-Path $EnvFile)) { throw ".env 파일이 없습니다: $EnvFile" }
if (-not (Test-Path $DbFile)) { throw "simbangbot.db 파일이 없습니다: $DbFile" }

Write-Host "[1/6] 서버 접속 확인"
ssh $Server "echo SSH_OK && uname -a"

Write-Host "[2/6] 서버 설치 스크립트 실행"
$remote = 'tmp=$(mktemp -d); git clone --depth 1 --branch ' + $Branch + ' ' + $RepoUrl + ' "$tmp/mingbot"; sudo bash "$tmp/mingbot/setup_server.sh" ' + $RepoUrl + ' ' + $Branch + '; rm -rf "$tmp"'
ssh $Server $remote

Write-Host "[3/6] 기존 DB 업로드"
scp $DbFile "${Server}:/tmp/simbangbot.db"
ssh $Server "sudo systemctl stop simbangbot 2>/dev/null || true; sudo install -m 0640 /tmp/simbangbot.db /var/lib/simbangbot/simbangbot.db; sudo chown \$(id -un):\$(id -gn) /var/lib/simbangbot/simbangbot.db; rm -f /tmp/simbangbot.db"

Write-Host "[4/6] 기존 .env 업로드 후 서버 경로/API 치환"
scp $EnvFile "${Server}:/tmp/simbangbot.env"
$envFix = @'
sudo install -m 0600 /tmp/simbangbot.env /etc/simbangbot/simbangbot.env
sudo chown $(id -un):$(id -gn) /etc/simbangbot/simbangbot.env
rm -f /tmp/simbangbot.env
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/simbangbot/simbangbot.env')
text=p.read_text(encoding='utf-8')
values={
'MINGBOARD_API_URL':'https://mingboard.vercel.app/api/mingbot/participation',
'MINGBOARD_BOSS_API_URL':'https://mingboard.vercel.app/api/mingbot/boss-times',
'MINGBOARD_HEARTBEAT_API_URL':'https://mingboard.vercel.app/api/mingbot/heartbeat',
'GOOGLE_CREDENTIALS_FILE':'/etc/simbangbot/google-service-account.json',
'SIMBANGBOT_DB_PATH':'/var/lib/simbangbot/simbangbot.db',
}
lines=text.splitlines()
seen=set()
out=[]
for line in lines:
    if '=' in line and not line.lstrip().startswith('#'):
        k=line.split('=',1)[0].strip()
        if k in values:
            out.append(f'{k}={values[k]}'); seen.add(k); continue
    out.append(line)
for k,v in values.items():
    if k not in seen: out.append(f'{k}={v}')
p.write_text('\n'.join(out)+'\n',encoding='utf-8')
PY
'@
ssh $Server $envFix

if (Test-Path $GoogleFile) {
    Write-Host "[5/6] Google 서비스 계정 JSON 업로드"
    scp $GoogleFile "${Server}:/tmp/google-service-account.json"
    ssh $Server "sudo install -m 0600 /tmp/google-service-account.json /etc/simbangbot/google-service-account.json; sudo chown \$(id -un):\$(id -gn) /etc/simbangbot/google-service-account.json; rm -f /tmp/google-service-account.json"
} else {
    Write-Warning "google-service-account.json이 로컬 폴더에 없어 Google Sheet 연동 파일 업로드는 건너뜁니다."
}

Write-Host "[6/6] 서비스 시작 / 상태 확인"
ssh $Server "sudo systemctl restart simbangbot && sleep 3 && sudo systemctl --no-pager --full status simbangbot"

Write-Host "완료. 실시간 로그: ssh $Server 'sudo journalctl -u simbangbot -f'" -ForegroundColor Green
