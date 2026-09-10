---
tags: [mysql, 락, 동시성]
---
# MySQL 네임드 락 (GET_LOCK) #stub

> [[Redis 분산락]] · [[Outbox 패턴]] 와 연결. 인프라 추가 없이 "여러 인스턴스 중 하나만 실행"을 만드는 가장 싼 방법.

## 1. 무엇인가
```sql
SELECT GET_LOCK('이름', 타임아웃초);   -- 1: 획득, 0: 실패(타임아웃), NULL: 에러
SELECT RELEASE_LOCK('이름');           -- 1: 해제, 0: 내 락 아님, NULL: 없음
```
- 서버 전체에서 유일한 이름의 **어드바이저리 락**. 테이블·행과 무관하고 앱이 의미를 부여
- **커넥션(세션)에 묶인다.** 커넥션이 끊기면 자동 해제 → 프로세스가 죽어도 영구 잠김 없음 (TTL 불필요)
- 타임아웃 0이면 기다리지 않고 바로 포기

## 2. 용도 — tick 단위 리더 선출
여러 파드가 같은 주기 작업(예: Outbox 릴레이 폴링)을 돌릴 때 중복 실행을 막는다.
```
매 tick:
  GET_LOCK('relay:<서비스>', 0) == 1 이면 → 작업 → RELEASE_LOCK
  아니면 → 이번 tick 건너뜀
```
- 인프라 0, 코드 몇 줄, 오토스케일로 파드 수가 바뀌어도 무관, 파드가 죽으면 커넥션 종료로 자동 인계
- tick마다 리더가 바뀔 수 있지만 한 tick에 하나만 실행되므로 문제없음. 순서도 유지(실행자가 하나)

## 3. 주의점
- **`GET_LOCK`과 `RELEASE_LOCK`은 같은 커넥션에서.** 커넥션 풀에서 매번 다른 커넥션을 받으면 해제가 안 된다 → 하나의 커넥션(QueryRunner 등)을 열어 락·작업·해제를 그 안에서
- 같은 MySQL 인스턴스를 여러 서비스가 쓰면 **락 이름에 서비스명**을 넣어 충돌 방지
- **RDS Proxy**를 쓰면 `GET_LOCK`이 세션 고정(pinning)을 유발한다. 동작엔 문제없지만 프록시의 커넥션 공유 이점이 그 세션에서 사라짐
- MySQL 5.7.5 이전은 세션당 락 하나뿐(새 GET_LOCK이 기존 락을 해제). 8.0은 여러 개 가능

## 4. 대안 — `FOR UPDATE SKIP LOCKED`
행 단위로 일을 나눠 갖는 방식. `SELECT … WHERE status='pending' ORDER BY id LIMIT n FOR UPDATE SKIP LOCKED`로 파드마다 다른 행을 잡는다.
- 처리량은 병렬로 늘지만 **같은 키의 행이 파드 간에 갈려 발송 순서가 섞일 수 있다**
- processing 표시 후 파드가 죽으면 그 행이 영원히 processing → 타임아웃 후 pending 복귀 로직이 추가로 필요
- 순서가 필요하거나 물량이 크지 않으면 네임드 락 리더 선출이 단순하다

## 복습 질문 #flashcards
- 네임드 락에 TTL이 필요 없는 이유는? :: 커넥션에 묶여 있어 프로세스가 죽으면 커넥션 종료로 자동 해제.
- GET_LOCK/RELEASE_LOCK을 같은 커넥션에서 해야 하는 이유는? :: 락이 세션 단위라 다른 커넥션에서 RELEASE하면 내 락이 아니어서 안 풀림.
- SKIP LOCKED 분배 대신 리더 선출을 고르는 이유는? :: 같은 키의 행이 파드 간에 갈려 순서가 섞이고 stale 복구 로직이 필요해서.

## 출처
- MySQL Locking Functions: https://dev.mysql.com/doc/refman/8.0/en/locking-functions.html
- InnoDB Locking Reads (SKIP LOCKED): https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html
- RDS Proxy pinning: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-proxy-pinning.html
