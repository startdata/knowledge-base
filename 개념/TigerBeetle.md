---
tags: [오픈소스, 원장, DB]
---
# TigerBeetle #stub

> [[이중기입 원장]] 와 연결.

금융 거래(이중기입 원장) 전용 분산 데이터베이스. Zig로 작성, Viewstamped Replication 합의, 초당 최대 100만 거래를 목표로 설계. 이중기입·불변성을 DB 수준에서 강제한다.
- 참고 가치: 원장 설계 원칙(계정·전표·잔액 파생·불변).
- 도입하지 않은 이유: 월 수만 전표 이하 규모에서 성능 이점이 없고, 운영 경험이 드문 분산 DB를 하나 더 갖게 되며, 정산 모듈이 다른 서버로 갈 때 함께 따라가야 한다. MySQL 테이블 + 단일 write 경로 + 일 검증 배치로 같은 규칙을 지킬 수 있다.
- 비슷한 범주: Formance Ledger(오케스트레이션 + 원장), Blnk(오픈소스 이중기입 원장), Square Books(공개 API, 비오픈소스), Uber LedgerStore(비공개).

출처: [tigerbeetle.com](https://tigerbeetle.com/), [docs](https://docs.tigerbeetle.com/)
