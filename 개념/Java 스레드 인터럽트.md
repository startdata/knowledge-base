---
tags: [java, 동시성, 종료처리]
---
# Java 스레드 인터럽트 #stub

> [[재시도 전략]] · [[Kinesis 컨슈머]] §6 와 연결.
> 세션: [[세션/씨드앤-액션이력-파이프라인/BE-570-컨슈머-차단재시도]]

## 1. 메커니즘
- `thread.interrupt()`는 스레드를 죽이지 않는다. **플래그를 세우고**, `sleep`/`wait`/`join` 같은 차단 호출 중이면 `InterruptedException`을 던지게 한다. 이때 **플래그는 지워진다.**
- `Thread.interrupted()`(static)는 플래그를 읽고 **지운다**. `isInterrupted()`는 읽기만 한다.
- `ExecutorService.shutdownNow()`는 실행 중 작업의 스레드를 인터럽트한다 — 협조적 종료. 작업이 플래그를 무시하면 안 끝난다.

## 2. 차단 루프에서의 규칙
1. `InterruptedException`을 잡아 삼키지 않는다. 처리할 수 없으면 **`Thread.currentThread().interrupt()`로 플래그를 복원**하고 예외(런타임)로 바꿔 올린다. 복원하지 않으면 상위(예: KCL, 풀 실행기)는 종료 요청을 모른다.
2. 상위의 **`catch (Exception e)`가 그 예외를 "작업 실패"로 오분류하지 않게** 한다. 차단 재시도 루프에서 인터럽트로 깨어난 예외를 실패로 취급해 DLQ에 보내면, 일시 장애가 영구 실패로 위장된다. 플래그가 복원된 상태이므로 다음 차단 호출도 즉시 던져 **배치 나머지가 연쇄로 실패**한다.
3. 분기 방법: catch에서 `Thread.currentThread().isInterrupted()`를 확인해 종료 경로(부수효과 없이 return)로 보낸다. 전용 예외 타입을 두는 것도 방법이지만, 플래그 확인은 예외 타입에 의존하지 않아 라이브러리 경계를 넘어도 동작한다.
4. 테스트에서 인터럽트를 흉내 냈으면 마지막에 `Thread.interrupted()`로 플래그를 지운다 — 안 지우면 같은 스레드의 다음 테스트가 오염된다. 이 호출은 "플래그가 세워져 있었다"는 단언으로도 쓸 수 있다.

## 복습 질문 #flashcards
- `InterruptedException`을 잡은 뒤 다시 `interrupt()`를 부르는 이유는? :: 예외가 던져질 때 플래그가 지워지므로, 상위가 종료 요청을 알 수 있게 복원한다.
- 차단 재시도 루프의 `catch (Exception)`이 위험한 이유는? :: 인터럽트(종료 신호)를 실패로 오분류해 격리·연쇄 실패를 만든다. 플래그를 확인해 분기한다.
- `Thread.interrupted()`와 `isInterrupted()`의 차이는? :: 전자는 읽고 지움(static), 후자는 읽기만.

## 출처
- Java Tutorials — Interrupts: https://docs.oracle.com/javase/tutorial/essential/concurrency/interrupt.html
- `Thread.interrupt()`/`interrupted()` javadoc: https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Thread.html#interrupt()
- `ExecutorService.shutdownNow()`: https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/concurrent/ExecutorService.html#shutdownNow()
