---
tags: [분산트랜잭션, 보상]
---
# Saga 패턴 #stub

> [[Outbox 패턴]] · [[멱등성]] · [[복합결제 전부-또는-전무]] 와 연결.

여러 서비스에 걸친 작업을 로컬 트랜잭션의 연쇄로 나누고, 중간 실패 시 이미 끝난 단계를 **보상 트랜잭션**(역연산)으로 되돌리는 패턴. 오케스트레이션(중앙 조정자) / 코레오그래피(이벤트 연쇄) 두 방식.
- 보상 연산 자체가 멱등해야 한다(재시도 가능).
- 되돌릴 수 없는 단계(PG 승인)는 보상이 "취소 API"이고, 취소도 실패할 수 있으므로 `COMPENSATING` 같은 중간 상태가 필요하다.
- 결제 흐름이 2~3단계(청구 → 결제 → 이용권)면 Saga 프레임워크(Temporal 등)는 과하다. outbox + 상태 기계 + 보상 명령으로 충분.
- 카카오페이는 결제 인증 후 잔액 차감·정산 예약·포인트 적립을 단계적으로 진행하는 데 Saga를 쓴다고 밝혔다.

출처: [Temporal Saga](https://temporal.io/blog/mastering-saga-patterns-for-distributed-transactions-in-microservices), [카카오페이](https://tech.kakaopay.com/post/msa-transaction/)
