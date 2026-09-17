---
tags: [테스트, docker, 통합테스트, java]
---
# Testcontainers #stub

> [[Spring DataAccessException 계층]] · [[테스트 디렉토리 구조]] · [[멱등성]] 와 연결.
> 세션: [[세션/씨드앤-액션이력-파이프라인/BE-570-컨슈머-차단재시도]]

## 1. 무엇을 IT로 고정하나
mock 단위 테스트는 **내가 고른 예외·내가 쓴 SQL 문자열**을 검증한다. 실제 DB에서만 확인되는 것은 따로 있다:
- 드라이버가 실제로 던지는 예외 클래스와 Spring 번역 결과(→ 재시도/격리 분류)
- 서버 모드에 따른 동작(MySQL STRICT의 잘림 거부 vs 비STRICT의 조용한 잘림)
- DDL 스크립트가 그대로 실행되는지(주석·인용 이스케이프 포함), 컬럼 타입 ↔ JDBC 타입 매핑
- 재전달·dedup·부분 실패가 실제 행 수·값으로 어떻게 남는지
DDL은 **문서의 원본 파일을 테스트가 직접 읽어** 실행하면 복사본 드리프트가 없다(`ScriptUtils.executeSqlScript` + `FileSystemResource`). 단 그 파일이 git에 있어야 CI에서도 읽힌다.

## 2. "Docker 없음"으로 조용히 skip되는 함정
- `@Testcontainers(disabledWithoutDocker = true)`는 Docker를 못 찾으면 테스트를 **skipped**로 만든다. 빌드는 초록불이다. **`check` 통과 ≠ IT 통과** — 결과 보고 때 skipped 수를 같이 본다.
- Docker가 켜져 있어도 skip될 수 있다: 빌드가 docker-java의 `api.version`을 고정(예 1.44)했는데 로컬 데몬의 최대 API 버전이 그보다 낮으면(Docker 24.0.x = 1.43) 클라이언트가 거부돼 "Docker 없음"으로 판정된다. `docker version --format '{{.Server.APIVersion}}'`로 확인하고 맞춰 준다.
- Gradle `test`는 입력이 같으면 UP-TO-DATE로 **이전 결과를 재사용**한다. 환경만 바꿔 재검증할 때는 `cleanTest`를 앞에 붙인다.

## 3. 장애 흉내 — `docker pause`
컨테이너를 `pauseContainerCmd`로 멈추면 프로세스가 SIGSTOP 상태가 된다. TCP 연결은 받아들여지지만 응답이 오지 않아 **핸드셰이크 대기**가 된다 → 클라이언트 `socketTimeout`으로 끊어야 테스트가 진행된다. 풀 없는 `DriverManagerDataSource` + `connectTimeout`/`socketTimeout` URL 파라미터 조합이 단순하다. pause 시간은 socketTimeout보다 **길게** 잡아야 첫 시도가 확실히 실패하고 재시도 경로를 탄다(짧으면 unpause 후 첫 시도가 그냥 성공해 재시도 카운터가 0). 별도 스레드에서 처리 → `join(timeout)` → `isAlive()`로 판정하고, `@Timeout`으로 무한 대기를 막는다.

## 4. MySQL 모듈 메모 (1.21.x)
- `MySQLContainer`는 `configure()`에서 command를 건드리지 않으므로 `withCommand("--sql-mode=…")`가 안전하다. mysql 공식 이미지 entrypoint가 `-`로 시작하는 인자를 `mysqld` 옵션으로 넘긴다.
- `withUrlParam("connectTimeout","1000")`은 `JdbcDatabaseContainer`의 것. `withInitScript`는 클래스패스 경로만 받는다 → 파일시스템 DDL은 `ScriptUtils`.
- 1.x 아티팩트는 `org.testcontainers:mysql`, 2.x부터 `testcontainers-mysql`로 개명.
- `mysql:8.4` 기동 가능 — 모듈 기본 my.cnf에 8.4에서 제거된 `default_authentication_plugin`이 없다.

## 복습 질문 #flashcards
- Docker가 켜져 있는데 Testcontainers IT가 skip되는 흔한 원인은? :: 고정한 Docker API 버전이 데몬 최대 버전보다 높아 클라이언트가 거부됨.
- `docker pause`로 DB 순단을 흉내 낼 때 pause 시간 기준은? :: socketTimeout보다 길게 — 첫 시도가 확실히 실패해야 재시도 경로가 검증된다.
- mock 단위 테스트가 못 잡고 실 DB IT만 잡는 것은? :: 드라이버 예외 클래스 → Spring 번역 결과, 서버 모드(STRICT) 동작, DDL 실행 가능성.

## 출처
- JUnit 5 통합(`disabledWithoutDocker`): https://java.testcontainers.org/test_framework_integration/junit_5/
- MySQL 모듈: https://java.testcontainers.org/modules/databases/mysql/
- MySQLContainer 1.21.3 소스: https://github.com/testcontainers/testcontainers-java/blob/1.21.3/modules/mysql/src/main/java/org/testcontainers/containers/MySQLContainer.java
- mysql 공식 이미지(플래그 전달): https://hub.docker.com/_/mysql
- docker-java `api.version` 동작·Gradle UP-TO-DATE는 세션에서 동작으로 확인 — 문서 링크 검증 필요 ?
