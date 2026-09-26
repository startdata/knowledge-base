# CloudWatch 경보 (Alarms)

지표가 조건을 넘으면 상태를 바꾸고, 상태가 바뀔 때 동작(SNS 알림, EC2 작업 등)을 실행한다.

## 상태와 알림 — "바뀔 때만" 울린다
- 상태: `OK` / `ALARM` / `INSUFFICIENT_DATA`(데이터 부족)
- 동작은 **상태 전이 때만** 실행된다. 정상이 계속되거나 장애가 계속돼도 반복 알림은 없다.
  - 장애 1번(OK → ALARM), 복구 1번(ALARM → OK)
  - 처음 만들 때 `INSUFFICIENT_DATA → OK`로 바뀌며 OK 알림이 한 번 올 수 있다(연결 확인 신호).
- **복구 알림을 받으려면 OK 상태 알림을 따로 추가**해야 한다.
- 반복 알림이 없으니 첫 알림을 놓치면 계속 모른다 → 채널 푸시 알림을 켜 둔다.
- 기준선 근처를 오르내리는 지표는 ALARM ↔ OK가 반복될 수 있다 → 아래 M/N으로 줄인다.

## 설정 항목
| 항목 | 의미 | 고르는 요령 |
|---|---|---|
| 통계 | 기간 안의 값을 어떻게 요약할지 | "한 번이라도"는 최소/최대, 추세는 평균 |
| 기간 | 한 데이터 포인트의 길이 | 빨리 변하면 1분, 천천히 변하면 5분 |
| 조건·임계값 | `<`, `>`, `>=` 등 | 지표 단위 확인 (예: `FreeStorageSpace`는 **바이트**) |
| 데이터 포인트 M/N | 최근 N개 중 M개가 조건을 넘으면 ALARM | 잠깐 튀는 값을 무시하려면 5/5처럼 연속 조건 |
| 누락 데이터 처리 | 데이터가 없을 때 어떻게 볼지 | 헬스체크처럼 "안 오면 장애"면 불량 처리, 일반 지표는 누락(기본값) |

- 값이 0/1뿐인 지표(`HealthCheckStatus`)에 `< 1`을 걸면 최소와 평균의 결과가 같다. 의도("한 번이라도 실패")를 드러내려면 최소가 낫다(AWS 문서 권장도 Minimum).

## 동작 종류
- SNS 알림 (상태별로 여러 개)
- **EC2 작업**: 복구 / 재부팅 / 중지 / 종료 — 종료를 잘못 고르면 인스턴스가 삭제된다
- Auto Scaling, Lambda, Systems Manager 등

## EC2 자동 복구 (`StatusCheckFailed_System` + 복구 작업)
- 시스템 상태 검사 = AWS 쪽 하드웨어·네트워크 문제. 인스턴스 상태 검사(`_Instance`, OS 문제)와 구분한다.
- 복구하면 인스턴스를 정상 하드웨어로 옮긴다. **인스턴스 ID, 사설 IP, 탄력적 IP, EBS 데이터는 유지**되고 메모리는 사라진다(재부팅과 같음).
- 그래서 **앱이 부팅 시 자동으로 떠야** 의미가 있다. → [[PM2 부팅 자동 시작]]

## 요금 (2026-09 요금표)
- 표준 해상도 경보 지표 1개당 $0.10/월, **계정당 10개 무료**.
- AWS가 기본으로 보내는 지표(EC2·RDS·Route 53)는 무료.

## 알림 테스트 — 실제 장애 없이
```bash
aws cloudwatch set-alarm-state --alarm-name <이름> \
  --state-value ALARM --state-reason "알림 테스트" --region <리전>
```
상태만 바뀌고, 다음 평가 때 실제 지표 기준으로 되돌아간다(OK 알림도 같이 확인됨).

## 관련
[[Route 53 상태 검사]] · [[AWS 알림 파이프라인]] · [[PM2 부팅 자동 시작]] · [[커넥션 풀 크기 산정]]

#flashcards
- Q: 장애가 30분 계속되면 알림이 몇 번 오나? → A: 1번(상태 전이 때만).
- Q: 복구 알림을 받으려면? → A: OK 상태에 대한 알림을 별도로 추가.
- Q: 서버를 건드리지 않고 알림 경로를 테스트하는 방법? → A: `aws cloudwatch set-alarm-state`.
- Q: EC2 복구 작업 후에도 서비스가 안 살아나는 흔한 이유? → A: 앱이 부팅 시 자동 시작되지 않음.

## 출처
- [Using Amazon CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [Recover your instance (EC2)](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-recover.html)
- [CloudWatch Pricing](https://aws.amazon.com/cloudwatch/pricing/)

#stub
