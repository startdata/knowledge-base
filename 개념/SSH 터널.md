# SSH 터널 (로컬 포트 포워딩)

외부에서 직접 닿지 않는 서버(예: 비공개 RDS)에, **접속 가능한 서버(배스천, 보통 EC2)를 통로로** 접속하는 방법.

## 구조
```
내 PC:5433 ──SSH──▶ EC2(배스천) ──▶ RDS:5432 (같은 VPC 안에서만 접근 가능)
```
```bash
ssh -i key.pem -N -L 5433:<RDS엔드포인트>:5432 ubuntu@<EC2 IP>
# 이후 DB 클라이언트는 localhost:5433 으로 접속
```
- `-L 로컬포트:목적지호스트:목적지포트` — 목적지 주소는 **배스천 입장에서** 해석된다. 그래서 RDS 엔드포인트를 그대로 쓴다.
- `-N` — 원격 명령 없이 터널만 유지

## 왜 RDS를 공개하지 않고 터널을 쓰나
- RDS "퍼블릭 액세스"를 켜면 운영 DB가 인터넷에 노출되고, 접속 IP가 바뀔 때마다 보안 그룹을 고쳐야 한다.
- 터널은 이미 열려 있는 SSH(22) 하나만 쓴다. DB 포트는 VPC 밖으로 나가지 않는다.

## GUI 클라이언트 설정 (TablePlus, DBeaver 등)
칸이 두 벌이라 헷갈린다.
| 영역 | Host | User | 인증 |
|---|---|---|---|
| DB (위쪽) | **RDS 엔드포인트**, 5432 | DB 사용자 | DB 비밀번호 |
| SSH (Over SSH) | **EC2 IP**, 22 | OS 사용자 (Ubuntu AMI는 `ubuntu`, Amazon Linux는 `ec2-user`) | `.pem` 키 |

## 처음 접속할 때 뜨는 "The server is unknown"
- 처음 보는 서버라서 **host key 지문(fingerprint)**을 확인하라는 뜻이다. 허용하면 저장되고, 나중에 같은 주소에서 지문이 바뀌면 경고한다(중간자 공격 방지).
- 검증 방법: 서버에서 `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub`, 또는 밖에서 `ssh-keyscan <IP> | ssh-keygen -lf -`로 지문을 구해 비교한다.
- EC2를 새로 만들면 지문이 바뀌는 게 정상이다.

## 자주 나는 에러
| 에러 | 원인 |
|---|---|
| `Permission denied (publickey)` | OS 사용자 이름 또는 키 파일이 틀림 |
| DB 단계 timeout | 터널 없이 RDS에 직접 접속 시도 |
| `no pg_hba.conf entry ... no encryption` | SSL 필요 → SSL 모드 `require` |

## 관련
[[SSH 멀티 계정 설정]]

#flashcards
- Q: `-L 5433:rds-host:5432`에서 rds-host는 누구 기준으로 해석되나? → A: SSH 서버(배스천) 기준.
- Q: EC2 브라우저 접속(Instance Connect)만 써 왔다면 TablePlus 터널에 무엇이 필요한가? → A: 인스턴스 키 페어 `.pem` 파일(Instance Connect는 임시 키를 자동 주입하므로 .pem이 없을 수 있다).

## 출처
- [OpenSSH ssh(1) — -L 옵션](https://man.openbsd.org/ssh)
- [AWS — Connect to a private RDS DB instance through a bastion (re:Post)](https://repost.aws/knowledge-center/rds-connect-ec2-bastion-host-private) — URL 검증 필요

#stub
