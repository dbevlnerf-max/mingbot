# 밍봇 Linux 서버 배포

운영 구조:

`Windows 로컬 개발 → GitHub dbevlnerf-max/mingbot → Linux 서버 git pull → systemd 밍봇`

밍보드 API는 서버에서 `https://mingboard.vercel.app/api/mingbot/...` 를 사용합니다.

## 서버 배치 경로
- 코드: `~/mingbot`
- 환경변수: `/etc/simbangbot/simbangbot.env`
- SQLite DB: `/var/lib/simbangbot/simbangbot.db`
- Google 서비스계정 JSON: `/etc/simbangbot/google-service-account.json`
- 서비스: `simbangbot.service`

## RVC / 음성
- `edge-tts`, FFmpeg, Discord voice 의존성을 requirements/setup에 포함합니다.
- Linux 서버에 RVC가 없어도 봇은 종료되지 않습니다.
- 음성 프로필이 `ming`이어도 RVC 구성 파일이 없으면 자동으로 Edge TTS로 대체됩니다.
- 기존 `ming_signature.wav` 파일이 서버에 없으면 시그니처도 TTS로 대체됩니다.
- RVC를 나중에 서버에 설치하면 `RVC_ROOT`, `RVC_PYTHON`, `RVC_CLI`, `RVC_MODEL` 환경변수만 지정하면 됩니다.

## 기존 로컬 데이터 이전
서비스 전환 시 반드시 로컬 봇을 먼저 종료한 뒤 최종 `simbangbot.db`를 복사하세요.
`install_from_windows.ps1`가 DB, `.env`, Google JSON 업로드와 경로 치환을 자동화합니다.

## Windows PowerShell에서 자동 설치
예:

```powershell
.\install_from_windows.ps1 -Server "사용자명@서버IP" -LocalBotFolder "C:\심방봇"
```

이 스크립트는 서버에 SSH 접속하고 Git clone, venv, requirements, FFmpeg, systemd 등록, DB/.env/Google JSON 이전, 서비스 시작까지 수행합니다.

## 중요한 비밀값
`MINGBOT_API_SECRET`는 밍보드(Vercel)의 `MINGBOT_API_SECRET`와 같은 값이어야 합니다.
GitHub에는 `.env`, DB, Google JSON을 올리지 않습니다.
