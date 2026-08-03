# MySQL-Python 실무 함정

pymysql 기반 파이썬 코드에서 실제로 크래시·오작동을 낸 MySQL 특성 모음. (partners-web-agent 실측)

## 집계 함수의 Decimal 반환 → sqlite 바인딩 크래시
- `AVG()`·`ROUND()`뿐 아니라 **`SUM()`도 Decimal**을 돌려준다 (`COUNT()`만 int).
- `decimal.Decimal`은 sqlite3 파라미터 바인딩이 지원하지 않아 `ProgrammingError`로 죽는다.
- MySQL 조회 결과를 sqlite/JSON에 넘길 때는 숫자 컬럼 전부 `float()`/`int()` 변환을 거친다.
  같은 계열 크래시를 한 프로젝트에서 **두 번** 냈다(temp_findings 저장, panel_journal exceedCnt) — 저장 경계마다 변환 헬퍼를 두는 게 답.

## MySQL 8 예약어 — 컬럼명 백틱
- `system`이 MySQL 8 예약어라 `SELECT system FROM ...`이 1064 문법 오류. `` `system` ``으로 인용.
- dev 실측에서만 잡혔다 — 스키마 문서만 보고 SQL을 쓰면 못 잡는 부류. 새 컬럼 SQL은 실 DB에 1회 실행해보는 게 싸다.

## insert-only 대용량 테이블의 창 조회는 스캔량이 유계
- "테이블이 수억 행"이어도 **조회 창을 최근 N분으로 고정하면 스캔량은 '창 내 행수'로 결정**된다
  (예: 센서 1만 대 × 5분 주기 → 30분 창 ≈ 6만 행) — 전제는 시간 컬럼 인덱스의 range scan(`EXPLAIN type=range`).
- 시간 컬럼 인덱스가 없어도 insert-only면 **PK(auto increment)가 시간과 단조 증가** → "창 시작 시각의 id를 이진탐색(프로브당 PK 조회 1회)으로 찾고 `id >= :minId`"로 우회 가능.
- `SET SESSION max_execution_time=<ms>`(SELECT 한정)을 안전망으로 걸고 실측.

관련: [[보조 인덱스]] · [[Text-to-SQL]]
출처: 실측 (MySQL 8.4.8, pymysql). 세션: 세션/partners-web-agent-관제봇/
#stub
