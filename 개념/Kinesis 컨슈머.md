---
tags: [aws, kinesis, 스트리밍, 컨슈머]
---
# Kinesis 컨슈머 #stub

> [[Kinesis 파티션 키]] · [[멱등성]] · [[Poison message]] · [[이벤트 순서 보장]] 와 연결.
> 세션: [[세션/씨드앤-액션이력-파이프라인/설계결정]]

## 1. 읽기 모델 — 샤드 이터레이터
Kinesis 읽기는 "위치 포인터"를 주고받는 방식이다.
```
GetShardIterator(stream, shardId, 위치 타입) → 불투명한 이터레이터 문자열
GetRecords(iterator, limit) → Records + NextShardIterator + MillisBehindLatest
다음 호출에 NextShardIterator 사용 … 반복
```
위치 타입: `TRIM_HORIZON`(보존 구간 처음) / `LATEST`(지금부터) / `AT_SEQUENCE_NUMBER` / `AFTER_SEQUENCE_NUMBER`(체크포인트 재개용) / `AT_TIMESTAMP`

- **이터레이터는 발급 후 5분 안에 쓰지 않으면 만료** → `ExpiredIteratorException`. 정상 루프는 매 호출마다 새것을 받으니 문제없고, DB 장애 재시도 backoff나 GC 정지로 5분 넘게 호출을 안 할 때 터진다 → 마지막 체크포인트로 `AFTER_SEQUENCE_NUMBER` 재발급
- 빈 `Records` + 유효한 `NextShardIterator`는 정상(아직 데이터 없음). `NextShardIterator == null`은 샤드 종료(리샤딩)
- 한도(표준 컨슈머): 샤드당 `GetRecords` **초당 5회**, **2MB/s**(같은 샤드의 컨슈머끼리 공유), 호출당 최대 10MB·10,000건. 초과 시 `ProvisionedThroughputExceededException` → backoff. 폴링 간격은 200ms 이상이면 됨

**설계 원칙: 이터레이터는 상태가 아니라 파생값.** 진짜 상태는 체크포인트뿐이고, 이터레이터는 언제든 체크포인트에서 다시 만들 수 있다. 만료·예외·재시작을 전부 "체크포인트에서 재발급"으로 통일하면 루프가 단순해진다.

## 2. 체크포인트 — 어디까지 처리했나
Kinesis는 at-least-once. 컨슈머가 "어디까지 처리 완료"를 스스로 기록해야 하고, 저장 성공 후에만 갱신해야 유실이 없다.

| 방식 | 장점 | 단점 |
|---|---|---|
| **목적지 DB에 체크포인트 테이블** (streamName, shardId → sequenceNumber) | 배치 저장과 **같은 트랜잭션**으로 갱신 → 저장/체크포인트 불일치 원천 차단 | 테이블 하나 추가 |
| **목적지 row에 시퀀스 번호 컬럼** (`MAX(seq) WHERE shardId=?`로 재개) | 테이블 추가 없음, 저장 자체가 체크포인트, row마다 출처 추적 가능 | row를 만들지 않는 레코드(중복·격리 건)가 배치 끝에 있으면 재시작 시 그만큼 재처리(멱등이라 무해). 샤드 종료는 `ListShards`로 판정 |
| 다른 저장소(DynamoDB 등) | KCL 표준 | 두 저장소 사이에 틈 |

시퀀스 번호는 자릿수가 긴 숫자 문자열이라 **`DECIMAL(65,0)`** 등 숫자형으로 저장해야 `MAX`가 맞다. VARCHAR면 문자열 비교로 틀린다.

## 3. 컨슈머 방식 3가지

| 방식 | 자동으로 해주는 것 | 운영 부담 |
|---|---|---|
| 직접 `GetRecords` 폴링 | 없음 — 샤드 목록, 체크포인트, 리샤딩 부모→자식 순서, 워커 간 분배 전부 직접 | 높음 |
| **KCL** (Kinesis Client Library) | DynamoDB **리스 테이블**로 샤드 분배·체크포인트, 리샤딩 순서, CloudWatch 지표 | 중간. DynamoDB 테이블 + 워커 상시. Java 네이티브(v2/v3), 타 언어는 MultiLangDaemon |
| **Lambda 이벤트 소스 매핑(ESM)** | 샤드 폴링·체크포인트·순서·재시도·실패 대상(SQS/SNS) | 가장 낮음. 서버 없음. 병렬도 = 샤드 수 × ParallelizationFactor |

- 소비 로직이 "멱등 upsert 하나"이고 순서에 의존하지 않는 설계면 KCL의 정교한 리스·순서 관리가 필요 없다 → ESM 또는 직접 폴링으로 충분
- 직접 폴링을 택하면 반드시: 체크포인트 영속화 + `AFTER_SEQUENCE_NUMBER` 재개 / 이터레이터 만료 재발급 / 호출 간격·스로틀 backoff / 배치 INSERT / 실패 분류 / 정상 종료 / `MillisBehindLatest`를 지표로 내보내기(IteratorAge 대용)
- 인스턴스는 샤드당 하나만. 둘이 같은 샤드를 읽으면 체크포인트가 뒤로 밀릴 수 있다(멱등이라 데이터는 안전, 낭비만)

KCL 체크포인트 규칙: 처리 성공 후에만 / 매 레코드가 아니라 배치마다 / `shardEnded`에서 반드시(안 하면 자식 샤드로 못 넘어감) / `leaseLost`에서는 금지 / `shutdownRequested`에서 체크포인트.

## 4. 리텐션과 회복 공식
기본 보존 24시간(최대 365일). 컨슈머가 멈췄다 재개할 때:
```
백로그 = 유입속도 R × 정지시간
회복시간 = 백로그 / (처리속도 − R)
```
처리속도가 유입의 **2배 미만이면 24시간 백로그를 24시간 안에 못 따라잡아** 앞쪽 데이터가 사라진다. 목표는 유입의 5배 이상 — 배치 INSERT면 자연히 달성. `GetRecords.IteratorAgeMilliseconds`가 컨슈머가 뒤처지는 유일한 조기 신호.

## 5. 샤드 증설 시 주의
Kinesis는 샤드를 "추가"하지 않고 **부모를 CLOSED로 만들고 자식으로 쪼갠다.** 키 재배치가 없어 한 키는 계속 한 샤드로만 간다(Kafka의 `hash % N`과 다름).
- **부모 샤드를 다 읽어야 자식 처리가 시작**된다 → 백로그가 쌓인 뒤 늘려도 즉시 빨라지지 않는다. IteratorAge가 쌓이기 **전에** 늘릴 것
- 전역 순서가 사라진다(샤드 1개일 때 우연히 성립하던 것). 처음부터 "키별 순서만 보장"을 전제로 설계
- `ListShards`로 동적 조회 필수. `ParentShardId`로 계보를 따라가야 한다
- 용량 공식: 레코드가 약 1KB보다 작으면 항상 **1,000 records/s**가 상한(1MB/s보다 먼저 걸림). 필요 샤드 = ceil(피크 rec/s ÷ 1000 × 안전계수 1.5~2)
- 피크 예측이 어려우면 on-demand 모드(기본 요금 높음)

## 복습 질문 #flashcards
- 샤드 이터레이터가 만료되는 조건과 대응은? :: 발급 후 5분 안에 안 쓰면 만료. 체크포인트로 AFTER_SEQUENCE_NUMBER 재발급.
- 체크포인트를 목적지 DB에 두는 이유는? :: 저장과 같은 트랜잭션으로 갱신해 "저장됐는데 체크포인트 못 찍음" 틈을 없앰.
- KCL이 대신해 주는 4가지는? :: 샤드 분배(리스), 체크포인트 저장, 리샤딩 부모→자식 순서, CloudWatch 지표.
- 처리속도가 유입의 2배 미만이면 왜 위험한가? :: 24h 리텐션 백로그를 24h 안에 못 따라잡아 데이터가 사라짐.
- 샤드를 늘려도 즉시 빨라지지 않는 이유는? :: 부모 샤드를 다 읽어야 자식 처리가 시작되므로.

## 출처
- GetShardIterator API: https://docs.aws.amazon.com/kinesis/latest/APIReference/API_GetShardIterator.html (이터레이터 5분 만료)
- GetRecords API: https://docs.aws.amazon.com/kinesis/latest/APIReference/API_GetRecords.html (한도, MillisBehindLatest)
- Quotas: https://docs.aws.amazon.com/streams/latest/dev/service-sizes-and-limits.html
- KCL: https://docs.aws.amazon.com/streams/latest/dev/shared-throughput-kcl-consumers.html
- Resharding: https://docs.aws.amazon.com/streams/latest/dev/kinesis-using-sdk-java-resharding.html
- Lambda ESM (Kinesis): https://docs.aws.amazon.com/lambda/latest/dg/with-kinesis.html
- 회복 공식·용량 공식은 세션 계산 — 검증 권장
