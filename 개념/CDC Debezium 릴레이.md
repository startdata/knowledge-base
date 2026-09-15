---
tags: [CDC, Outbox, Kafka]
---
# CDC(Change Data Capture) 릴레이 — Debezium #stub

> [[Outbox 패턴]] · [[Kafka 파티션과 컨슈머 그룹]] 와 연결.

outbox 테이블을 워커가 폴링하는 대신, DB 바이너리 로그(MySQL binlog)를 읽어 outbox INSERT를 Kafka로 자동 발행하는 방식. Debezium(Kafka Connect) 또는 MSK Connect.
- 장점: 폴링 지연·부하 없음, 거의 실시간.
- 단점: Connect 클러스터·커넥터 운영, binlog 보존 정책, 스키마 변경 시 커넥터 영향. 소규모(월 수천 건)에서는 폴링 릴레이(1~2초)가 충분하고 단순하다.
- 이벤트 원본은 여전히 DB(outbox)이고 CDC는 전달 수단만 바꾼 것. 재생 원천도 DB.

출처: [Confluent Transactional Outbox(CDC)](https://developer.confluent.io/courses/microservices/the-transactional-outbox-pattern/), 블로그([링크](https://medium.com/@subodh.shetty87/designing-reliable-distributed-systems-transactional-outbox-change-data-capture-cdc-pattern-0461b00cf059)) — 공식 문서 외 참고.
