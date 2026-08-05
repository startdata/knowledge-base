# contextvars (Python)

스레드-로컬(threading.local)의 비동기 시대 대체물. "현재 실행 흐름"에 붙는 값(ContextVar)들의 불변 매핑이 **Context**이며, 트레이싱·로깅 상관관계 같은 암묵적 컨텍스트 전파의 표준 기반이다.

## 핵심 사실
- `ContextVar.set()`은 현재 컨텍스트에만 반영. `copy_context()`로 현재 컨텍스트의 얕은 스냅샷을 뜨고, `Context.run(fn, *args)`로 그 컨텍스트 안에서 fn을 실행한다(내부 set은 그 Context에만 남음).
- **같은 Context 객체는 동시·재귀 진입 금지** — 둘 이상의 OS 스레드에서 동시에 `run()`을 부르거나 재귀 호출하면 `RuntimeError` (공식 문서 명시). → 여러 스레드가 같은 캡처본을 쓰려면 **호출마다 `ctx.copy().run(fn)`** 으로 사본을 만들어야 한다.
- **asyncio는 자동 전파**: `call_soon`·Task는 생성 시점의 현재 컨텍스트 사본에서 콜백을 실행한다 (`Loop.call_soon(context=...)` 문서 명시).
- **스레드는 자동 전파 없음**: `ThreadPoolExecutor` 워커는 제출자의 컨텍스트를 물려받지 않는다(워커 스레드는 재사용되며 자기 컨텍스트로 실행). 전파하려면 제출/빌드 시점에 `copy_context()`를 캡처해 `ctx.run(fn)`으로 감싸 넘겨야 한다. (3.14에서 Thread에 context 전달 옵션이 생겼다는 기억이 있으나 미확인 — ? 검증 필요)

## 파생 효과 — 관측 도구의 트레이스 끊김
OpenTelemetry Python의 현재-스팬 추적이 contextvars 기반이라, **스레드 풀에서 연 스팬은 부모를 잃는다**. OTEL 위에 있는 [[Langfuse]] v4도 동일 — 실측 진단·수정 패턴은 [[Langfuse]] 노트와 세션 기록 참조.

## 실전 패턴 (빌드 시점 바인딩)
```python
ctx = contextvars.copy_context()          # 부모 컨텍스트 안에서 캡처
def bound(*a):
    return ctx.copy().run(fn, *a)          # 호출마다 사본 — 동시 진입 안전
```
한계: 부모가 **캡처 시점 위치로 고정**된다(캡처 이후 열린 중간 스팬 아래로는 못 들어감).

#flashcards
- 같은 Context 객체를 여러 스레드에서 동시에 `run()`하면? :: RuntimeError — 동시·재귀 진입 금지. 호출마다 `ctx.copy().run()`으로 사본 사용.
- asyncio와 스레드 풀의 contextvars 전파 차이는? :: asyncio Task/call_soon은 생성 시점 컨텍스트 사본에서 실행(자동 전파), 스레드 풀 워커는 전파 없음(수동으로 copy_context 캡처 필요).

출처: docs.python.org/3/library/contextvars.html (Context.run 동시 진입 RuntimeError, asyncio 전파 서술). 스레드 풀 비전파는 공식 문서에 직접 서술이 없어(스레드 언급 부재) 실측(2026-08-04, prod Langfuse 고아 트레이스)으로 확인.
관련: [[Langfuse]]
#stub
