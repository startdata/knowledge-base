---
tags: [메시징, 정합성, 이벤트]
---
# Outbox 패턴 (Transactional Outbox) #stub

> [[멱등성]] · [[이벤트 순서 보장]] · [[Poison message]] · [[Kinesis 컨슈머]] 와 연결.
> 세션: [[세션/씨드앤-액션이력-파이프라인/설계결정]]

## 1. 문제 — dual write
하나의 작업이 **DB 쓰기**와 **메시지 발행** 두 시스템에 써야 할 때, 둘을 한 트랜잭션으로 묶을 수 없다(메시지 브로커는 DB 트랜잭션에 참여하지 않음).

| 순서 | 실패 시 |
|---|---|
| 발행 → 커밋 | 커밋 실패(롤백)하면 **일어나지 않은 일의 메시지**(유령 이벤트) |
| 커밋 → 발행 | 발행 전에 프로세스가 죽으면 **일어난 일의 메시지 유실** |
| 커밋 → fire-and-forget 발행 | in-flight 유실 (실측되는 경로) |

2PC는 대부분의 브로커가 지원하지 않고 실무에서도 쓰지 않는다.

## 2. 해법 — 같은 DB, 같은 트랜잭션에 이벤트를 쓴다
```
BEGIN
  UPDATE 비즈니스 테이블 ...
  INSERT INTO outbox (event_id, payload, status='pending') ...
COMMIT
```
- 비즈니스 변경과 이벤트가 **원자적으로 함께** 저장되거나 함께 롤백된다
- 별도 **릴레이**가 outbox의 pending 행을 읽어 브로커로 발행하고 complete로 표시한다
- 얻는 것: 정합성. 대가: 즉시성이 아니라 **최종 일관성**(릴레이 주기만큼 지연) → [[최종적 일관성]]

전제: 이벤트를 소비하는 저장소가 **원본 DB와 다른 곳**일 때 의미가 있다. 같은 DB면 같은 트랜잭션에 직접 INSERT하면 끝이라 Outbox도 브로커도 필요 없다.

## 3. 검증과 ID 발급은 "기록 시점"에
Outbox를 쓸 때 놓치기 쉬운 두 가지.

**검증 시점.** 스키마 검증을 릴레이(발송) 시점에 하면, 잘못된 payload가 비즈니스 변경과 함께 이미 커밋된 뒤에 걸린다 → 그 이벤트는 영구 발송 불가 = Outbox의 목적(정합성)이 깨진다. 검증은 **outbox INSERT 시점**에 해서 실패 시 비즈니스 트랜잭션까지 롤백시킨다. 트레이드오프: 이벤트 payload 오류가 기능을 막는다. 검증은 코드 경로에 결정적이라 운영이 아니라 개발 단계에서 터지므로 받아들일 만하다.

**이벤트 ID 발급 시점.** ID를 발송 시점에 만들면 재발송마다 ID가 달라져 "발송 시도의 신원"이 된다 → 소비자가 중복을 못 거른다. ID는 **INSERT 시점**에 만들어 outbox 행에 저장해야 "이벤트의 신원"이 되고, 몇 번 발송해도 같다. → [[멱등성]] [[UUID v7]]

발송 시점 재검증은 빼는 편이 낫다. 스키마를 엄격하게 바꾼 라이브러리를 배포하면 기록 당시 유효했던 pending 행이 발송 검증에서 떨어진다. 남긴다면 배포 전 pending drain 규칙이 필요하다.

## 4. 릴레이 방식 — 폴링 vs CDC

| | 폴링 릴레이 | CDC (Debezium Server / AWS DMS 등) |
|---|---|---|
| 추가 인프라 | 없음 (앱 안 루프) | 상시 실행 컴포넌트 + binlog 활성화·복제 권한 |
| 지연 | 폴링 주기 (초 단위) | 수백 ms |
| 순서 | 릴레이가 여럿이면 깨질 수 있음 → 리더 선출 필요 | binlog 커밋 순서 그대로 |
| 비용 | 폴링 쿼리 (인덱스 있으면 무시 가능) | 복제 인스턴스 상시 과금 |
| 운영 | 앱 코드 안에서 디버깅 | 커넥터 lag·offset·재시작 별도 관리 |

이벤트가 초 단위 지연을 허용하면 폴링이 맞다. CDC의 유일한 실질 이점(지연)이 가치가 없고 인프라만 는다. 밀리초 전파가 필요한 이벤트(결제 승인 등)면 CDC.

폴링 릴레이를 제대로 만드는 조건:
- 파드가 여럿이면 **중복 발송 방지** — [[MySQL 네임드 락]]으로 tick 단위 리더 선출, 또는 `SKIP LOCKED` 분배(순서 섞임 감수)
- 배치 크기 제한 + `ORDER BY id` (장애 복구 후 pending 폭증 대비)
- 브로커 부분 실패를 **레코드 단위**로 처리 (Kinesis `PutRecords`의 레코드별 ErrorCode 등)
- 커밋 직후 즉시 트리거 + 주기 폴링 병행하면 지연이 CDC에 근접
- 관측 지표 하나: **가장 오래된 pending 행의 나이** → 릴레이 정지·브로커 장애·폴링 지연을 전부 잡음

## 5. 상태 흐름과 보관 기간
```
pending ─발송 성공→ complete ─N일 후→ 삭제
   │ 발송 실패(일시)  → retry_count+1, pending 유지
   └ 인코딩 불가(영구) → failed (조회에서 제외, 알림, 수동 복구)
```
- complete 행을 바로 지우지 않고 보관하는 근거: **브로커 보존 기간보다 긴 소비자 장애** 때 재발송 소스가 된다. 보관 기간 = 브로커 보존 기간 + 장애 인지·복구 여유
- 매일 대사 배치(발송 완료 이벤트가 목적지에 실제 저장됐는지 대조 → 누락은 pending 복원)를 두면 "유실 0건"이 검증 가능한 주장이 된다
- 릴레이 단계 실패는 outbox의 `status`로 충분. 별도 테이블은 소비자 단계에서 필요 → [[Poison message]]

## 6. 관련 결정
- Outbox 테이블은 **서비스 DB마다** 둔다. 공용 Outbox DB는 분산 트랜잭션이 필요해져 패턴의 의미가 없다
- Outbox PK는 auto-increment, 이벤트 ID는 UNIQUE가 낫다. 매초 스캔되는 `(status, id)` 보조 인덱스에 CHAR(36) PK가 실리면 커지고, `ORDER BY id`가 정확한 삽입 순서 → [[보조 인덱스]]
- payload에는 발송할 envelope 전체를 넣는다. 원본 입력만 넣으면 릴레이가 ID·시각을 다시 붙여야 해 두 경로의 레코드 형태가 갈린다

## 복습 질문 #flashcards
- dual write 문제란? :: DB 커밋과 메시지 발행이 한 트랜잭션이 아니라 둘 중 하나만 성공하는 경우가 생김 (유령 이벤트 또는 유실).
- Outbox가 dual write를 없애는 원리는? :: 이벤트를 비즈니스 변경과 같은 DB·같은 트랜잭션에 쓰고, 발행은 릴레이가 나중에 한다.
- 검증을 기록 시점에 해야 하는 이유는? :: 발송 시점 검증이면 잘못된 이벤트가 이미 커밋된 뒤라 영구 발송 불가 = 정합성 목적이 깨짐.
- 이벤트 ID를 기록 시점에 발급해야 하는 이유는? :: 발송 시점 발급이면 재발송마다 ID가 달라져 소비자가 중복을 못 거름.
- 폴링 릴레이가 CDC보다 나은 조건은? :: 초 단위 지연 허용 + 인프라 추가 회피. CDC의 이점은 지연뿐.
- complete 행을 며칠 보관하는 근거는? :: 브로커 보존 기간보다 긴 소비자 장애 때 재발송 소스.

## 출처
- microservices.io — Transactional outbox: https://microservices.io/patterns/data/transactional-outbox.html
- Debezium — Outbox Event Router: https://debezium.io/documentation/reference/stable/transformations/outbox-event-router.html
- AWS DMS — Kinesis as target: https://docs.aws.amazon.com/dms/latest/userguide/CHAP_Target.Kinesis.html (CDC 대안 검토용)
- 검증·ID 발급 시점, 보관 기간 근거, 릴레이 조건은 세션 설계 논의에서 정리 — 공식 문서엔 없음, 검증 권장

## 한 DB 안에서 outbox는 무엇을 위한 것인가 (2026-09 추가, 결제 개편 설계)
> 세션: [[세션/leaf-결제개편/설계결정-서사]]

outbox의 본래 목적은 dual write(§1)다. **같은 DB 안의 두 모듈 테이블은 한 트랜잭션으로 정합성이 끝나므로, 그 사이에 outbox를 두는 이유는 정합성이 아니다.** 결제 설계에서 같은 DB의 모듈 사이에도 outbox → 릴레이 → inbox를 둔 이유는 셋이었다.
- **경계**: 모듈 A의 트랜잭션이 모듈 B의 테이블에 직접 쓰면 테이블 소유권이 깨지고, B를 다른 서버로 옮기는 날 그 쓰기 지점을 전부 찾아 고쳐야 한다. → [[모듈러 모놀리스]]
- **장애 격리**: B(정산 전표) 코드의 버그가 A(청구서 발행·결제)를 롤백시키면 안 된다. 떼어 두면 A는 커밋되고 B만 재처리 대상이 된다.
- **전달 수단 교체**: 발행 측이 outbox에만 쓰면, 릴레이의 목적지를 바꾸는 것(인프로세스 → Kafka)이 설정 변경으로 끝난다.

**릴레이의 목적지는 브로커가 아니어도 된다.** outbox는 "내 테이블에만 쓰고 나머지는 릴레이가 옮긴다"는 규칙이고, 테이블 + 릴레이 워커만 있으면 성립한다.

| 목적지 | 브로커 | 전달 보장 |
|---|---|---|
| 같은 DB의 상대 inbox 테이블 | 없음 | 릴레이가 outbox PUBLISHED 표시와 inbox INSERT를 **한 트랜잭션**에 → 정확히 한 번. inbox 유니크는 보험 |
| 상대 서버 HTTP 엔드포인트 | 없음 | at-least-once, inbox 유니크 필요 |
| SQS 등 관리형 큐 | 큐 | 같음 |
| Kafka | Kafka | 같음. 다수 소비자 팬아웃이 장점 |

**외부 API 호출(PG 승인)은 outbox·Kafka로 안전해지지 않는다.** 외부 호출을 안전하게 하는 것은 호출하는 모듈 안의 네 가지다: 호출 전 의도(attempt) 행을 PROCESSING으로 커밋, 호출은 어느 트랜잭션에도 속하지 않음, 같은 attempt 키를 외부 멱등키로 전달, 응답 부재 시 조회로 확정. outbox는 요청을 그 모듈까지 내구성 있게 **전달**할 뿐이다. → [[멱등성]] [[결제 상태 기계]]

비용: 같은 프로세스 안인데도 발행과 소비 사이에 수 초 간격이 생기고 배관 코드가 늘어난다. "모듈이 나중에 갈라진다"는 요구가 없었다면 직접 호출이 맞았을 선택이다.

출처: [AWS Transactional Outbox](https://docs.aws.amazon.com/prescriptive-guidance/latest/cloud-design-patterns/transactional-outbox.html), [Confluent Transactional Outbox](https://developer.confluent.io/courses/microservices/the-transactional-outbox-pattern/) — "같은 DB 모듈 간에도 쓰는 이유"는 설계 판단이며 공식 문서의 주장은 아니다.
