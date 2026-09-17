---
tags: [spring, jdbc, 예외, 재시도]
---
# Spring DataAccessException 계층 #stub

> [[재시도 전략]] · [[Kinesis 컨슈머]] §6 · [[Testcontainers]] 와 연결.
> 세션: [[세션/씨드앤-액션이력-파이프라인/BE-570-컨슈머-차단재시도]]

## 1. 왜 보나
"일시 실패는 재시도, 영구 실패는 격리"를 코드로 쓰려면 예외를 **클래스로** 분류해야 한다. Spring은 벤더별 `SQLException`을 하나의 `DataAccessException` 계층으로 번역해 주는데, **직관과 다른 자리에 있는 클래스가 두 개** 있어 재시도 분류에 구멍이 나기 쉽다.

## 2. 3분류

```
DataAccessException
├─ TransientDataAccessException          ← 재시도하면 성공할 수 있음
│    ├─ ConcurrencyFailureException (데드락·락 대기: DeadlockLoserDataAccessException, CannotAcquireLockException …)
│    ├─ QueryTimeoutException
│    └─ TransientDataAccessResourceException
├─ NonTransientDataAccessException       ← 같은 요청은 다시 실패
│    ├─ DataIntegrityViolationException (제약 위반, DuplicateKeyException, 잘림 …)
│    ├─ InvalidDataAccessResourceUsageException (BadSqlGrammarException …)
│    └─ NonTransientDataAccessResourceException
│         └─ DataAccessResourceFailureException   ← ★ "리소스 실패" — 커넥션 획득 실패가 여기
│              └─ CannotGetJdbcConnectionException
└─ RecoverableDataAccessException        ← ★ Transient도 NonTransient도 아닌 세 번째 갈래
```

- ★1 **`CannotGetJdbcConnectionException`은 NonTransient 계열이다.** 이름은 "일시적 연결 실패"처럼 들리지만 계층상 `NonTransientDataAccessException` 아래다. "Transient만 재시도"로 쓰면 **DB/프록시 순단 시 커넥션 획득 실패는 재시도 0회**로 즉시 실패한다.
- ★2 **`RecoverableDataAccessException`은 별도 뿌리다.** JDBC 4의 `SQLRecoverableException`("연결을 다시 열면 회복될 수 있음")을 그대로 번역한 것. MySQL Connector/J의 **`CommunicationsException`("Communications link failure", server has gone away 2006)이 `SQLRecoverableException`을 상속**하므로, **이미 빌린 커넥션으로 문장을 실행하는 도중 끊기면** 여기로 온다. Transient·ResourceFailure만 재시도하면 이 경로가 영구 실패로 격리된다.
- 커넥션 풀(Hikari)에서는 대여 시 검증을 건너뛰는 창(`aliveBypassWindow`, 기본 500ms)이 있어 끊긴 커넥션이 그대로 재대여될 수 있다 → ★2가 실제로 발생하는 이유. (Hikari 설정 이름은 리뷰 확인, 동작 세부는 검증 권장 ?)

**재시도 분류 함수는 세 갈래를 다 잡아야 한다:**
```java
e instanceof TransientDataAccessException
 || e instanceof DataAccessResourceFailureException
 || e instanceof RecoverableDataAccessException
```

## 3. 번역기 체인 — 어떤 SQLException이 어떤 클래스가 되나
`JdbcTemplate`(정확히는 `JdbcAccessor.getExceptionTranslator()`)의 기본 번역기:
1. **`SQLErrorCodeSQLExceptionTranslator`는 기본이 아니다.** 클래스패스 루트에 **사용자가 둔 `sql-error-codes.xml`이 있을 때만** 쓰인다(Spring 6.x). 번들된 벤더 코드 표는 그 경우에만 참조된다.
2. 기본은 **`SQLExceptionSubclassTranslator`** — JDBC 4 서브클래스(`SQLTransientException`/`SQLNonTransientException`/`SQLRecoverableException`…)로 1차 판정.
3. 서브클래스가 아니면 **`SQLStateSQLExceptionTranslator`** 로 폴백 — SQLState 앞 두 자리(클래스 코드)로 판정. 예: `"22"`·`"23"` → `DataIntegrityViolationException`, `"08"` → `DataAccessResourceFailureException`, `"42"` → `BadSqlGrammarException`.

예: MySQL `Data too long for column`(에러 1406, SQLState 22001)은 Connector/J가 `MysqlDataTruncation`(`java.sql.DataTruncation` ⊂ `SQLWarning`)으로 던진다 → JDBC 4 서브클래스가 아니라 SQLState 폴백 → `"22"` → **`DataIntegrityViolationException`** → 영구. (STRICT 모드여야 에러가 난다. 비STRICT면 잘려서 저장되고 경고만 남는다.)

커넥션 **획득** 실패는 번역기를 거치지 않는다 — `DataSourceUtils.getConnection`이 모든 `SQLException`을 `CannotGetJdbcConnectionException`으로 감싼다. 풀이 없는 `DriverManagerDataSource`에서 소켓 타임아웃이 나도 같은 클래스다.

## 4. 검증 방법 — javadoc URL을 인용했는데도 틀렸다
계획 단계에서 Spring javadoc을 인용해 "커넥션 실패 ⊂ `DataAccessResourceFailureException`"까지는 맞게 적었지만, "server has gone away"도 거기 속한다고 **추정**했다. 드라이버(Connector/J)가 어떤 `SQLException` 서브클래스를 던지는지는 Spring 문서에 없다. 리뷰에서 의존성 jar를 직접 열어(`unzip -p … | javap`) `CommunicationsException extends SQLRecoverableException`을 확인해 잡았다. **드라이버 예외 → Spring 클래스 매핑은 두 프로젝트 소스를 다 봐야 한다.** 단위 테스트는 내가 고른 예외 클래스를 던지므로 이 종류의 오류를 못 잡는다 — 실 DB 통합 테스트([[Testcontainers]])나 jar 확인이 필요하다.

## 복습 질문 #flashcards
- `CannotGetJdbcConnectionException`을 Transient만 재시도하는 코드가 놓치는 이유는? :: 계층상 NonTransient → DataAccessResourceFailureException 아래라서.
- MySQL 실행 중 연결이 끊기면 Spring 예외는? :: Connector/J CommunicationsException(SQLRecoverable) → RecoverableDataAccessException. Transient·ResourceFailure 어느 쪽도 아님.
- `sql-error-codes.xml`의 벤더 코드 표는 언제 쓰이나? :: 사용자가 클래스패스 루트에 그 파일을 둘 때만. 기본은 JDBC 서브클래스 → SQLState 순.
- MySQL 1406(Data too long)은 어떤 Spring 예외가 되나? :: SQLState 22001 → 클래스 "22" → DataIntegrityViolationException(영구).

## 출처
- Spring `DataAccessException` 계층 javadoc: https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/dao/DataAccessException.html
- `RecoverableDataAccessException`: https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/dao/RecoverableDataAccessException.html
- `CannotGetJdbcConnectionException`(계층 표시): https://docs.spring.io/spring-framework/docs/6.2.x/javadoc-api/org/springframework/jdbc/CannotGetJdbcConnectionException.html
- `SQLExceptionSubclassTranslator` / `SQLStateSQLExceptionTranslator`: https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/support/SQLExceptionSubclassTranslator.html · https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/support/SQLStateSQLExceptionTranslator.html
- `JdbcAccessor.getExceptionTranslator()`(사용자 `sql-error-codes.xml` 조건): https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/jdbc/support/JdbcAccessor.html
- Connector/J `CommunicationsException` 소스: https://github.com/mysql/mysql-connector-j/blob/release/9.x/src/main/user-impl/java/com/mysql/cj/jdbc/exceptions/CommunicationsException.java
- MySQL sql_mode STRICT: https://dev.mysql.com/doc/refman/8.4/en/sql-mode.html#sqlmode_strict_trans_tables
- HikariCP `aliveBypassWindow`: README의 시스템 프로퍼티 항목 https://github.com/brettwooldridge/HikariCP — 리뷰 인용, 검증 권장
