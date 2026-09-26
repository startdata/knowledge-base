# PM2 부팅 자동 시작

서버가 재부팅되거나 EC2 자동 복구(= 재부팅과 같음)가 일어나도 앱이 다시 뜨게 하는 설정.

## 설정 순서
```bash
pm2 startup          # 아무것도 바꾸지 않고, 실행할 sudo 명령 한 줄을 출력만 함
sudo env PATH=... pm2 startup systemd -u ubuntu --hp /home/ubuntu   # 출력된 줄을 그대로 실행
pm2 ls               # 앱이 online인지 확인
pm2 save             # 현재 목록을 ~/.pm2/dump.pm2 에 저장
systemctl is-enabled pm2-ubuntu   # enabled
```
- `pm2 startup`이 만드는 것: systemd 서비스 `pm2-<사용자>`. 부팅 때 `pm2 resurrect`로 **저장된 목록을 복원**한다.
- **`pm2 save`를 안 하면** 부팅은 돼도 복원할 목록이 없어서 아무것도 안 뜬다.
- 출력된 명령을 그대로 쓰는 이유: Node·PM2 설치 경로(PATH)가 서버마다 다르다.
- 서비스 이름은 **PM2를 실행한 사용자**에 따라 다르다(`pm2-ubuntu`, `pm2-root`). 확인: `ps -eo user,cmd | grep "[p]m2"`
- 되돌리기: `pm2 unstartup systemd` (출력 마지막 줄에 안내가 나와서, 복사할 때 딸려오지 않게 주의)
- 앱 앞의 프록시도 확인: `systemctl is-enabled nginx`

## 저장 목록(dump)에 들어가는 것 / 안 들어가는 것
| 변경 | `pm2 save` 다시 필요? | 이유 |
|---|---|---|
| 앱 추가·삭제 | **필요** | 목록 자체가 바뀜 |
| `ecosystem.config.js`의 `env_*` 변경 후 재시작 | **필요** | dump에는 저장 시점의 환경 변수가 들어 있음 |
| `.env` 파일 수정 (앱이 기동 시 읽는 파일) | 불필요 | 파일은 디스크에 있고, 앱이 켜질 때마다 새로 읽음 |
| `pm2 restart`로 배포 | 불필요 | 목록이 안 바뀜 |

- 저장 전에 앱이 `online`인지 확인한다. 꺼진 상태로 저장하면 재부팅 뒤에도 꺼져 있다.

## 관련
[[CloudWatch 경보]] (EC2 자동 복구) · [[헬스체크 설계]]

#flashcards
- Q: `pm2 startup`만 하고 `pm2 save`를 안 하면? → A: 부팅 시 복원할 목록이 없어 앱이 안 뜸.
- Q: `.env.prod`를 고친 뒤 `pm2 save`를 다시 해야 하나? → A: 아니다. 앱이 기동 때 파일을 읽는다. ecosystem env를 바꿨다면 필요.

## 출처
- [PM2 — Startup Script](https://pm2.keymetrics.io/docs/usage/startup/)
- [PM2 — Process Management (save / resurrect)](https://pm2.keymetrics.io/docs/usage/process-management/)

#stub
