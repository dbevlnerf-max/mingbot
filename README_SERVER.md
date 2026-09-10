# 심방봇 서버 배포 패키지

이 패키지는 현재 로컬 실행 중인 심방봇을 Linux 서버에서 24시간 실행하기 위한 구성입니다.

## 구성
- `bot.py` : 최신 심방봇
- `requirements.txt` : Python 패키지
- `.env.example` : 비밀값을 제외한 설정 예시
- `.gitignore` : 토큰/DB/로그가 GitHub에 올라가지 않도록 제외
- `simbangbot.service.template` : systemd 서비스
- `setup_server.sh` : 최초 서버 설치 자동화
- `update_server.sh` : 이후 git pull + requirements + 재시작 자동화

## 서버의 최종 위치
- 앱: `~/simbangbot`
- 환경변수: `/etc/simbangbot/simbangbot.env`
- DB: `/var/lib/simbangbot/simbangbot.db`
- 서비스: `simbangbot.service`

## 기존 로컬 DB를 유지하려면
현재 PC의 `simbangbot.db`를 서버의 `/var/lib/simbangbot/simbangbot.db`로 **최초 1회 복사**해야
보스시간/설정/참여기록을 그대로 이어갈 수 있습니다.

## 최초 설치 후
환경설정:
`sudo nano /etc/simbangbot/simbangbot.env`

서비스:
`sudo systemctl restart simbangbot`
`sudo systemctl status simbangbot`

로그:
`sudo journalctl -u simbangbot -f`
