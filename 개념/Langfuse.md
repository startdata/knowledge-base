# Langfuse

LLM 애플리케이션 **관측(observability) + 평가(evaluation)** 플랫폼. self-hosted(OSS) 또는 cloud.

## 핵심 데이터 모델
- **trace**: 한 번의 요청/실행 전체. 여러 observation을 트리로 담음.
- **observation**: trace 안의 단위 작업. 종류(`as_type`): `span`(일반)·`generation`(LLM 호출)·`tool`·`agent` 등.
- **score**: trace/observation에 붙는 평가 점수. `create_score(name, value, trace_id, data_type)`. type: NUMERIC/CATEGORICAL/BOOLEAN/TEXT. comment에 이유(reasoning) 저장.
- **session / user**: trace를 묶는 메타. session_id로 대화 흐름, user_id로 사용자별 조회.

## LangChain/LangGraph 통합 (v4)
- `langfuse.langchain.CallbackHandler`를 실행 config의 callbacks로 주입 → trace 자동 수집.
- v4에서 **인증(public/secret/host)은 CallbackHandler 생성자가 아니라 전역 `Langfuse()` 클라이언트 1회 초기화로 주입**. `CallbackHandler()`는 인자 없이 전역 클라이언트를 사용.
- trace 메타(session_id/user_id/trace_name/tags) 주입: **`propagate_attributes(...)` 컨텍스트 매니저**로 invoke를 감싸는 게 v4 권장. config metadata 방식(`langfuse_session_id` 등)은 공식 예시가 적음.

## span 직접 생성 (v4, 실측 4.12.0)
- `client.start_as_current_observation(name=..., as_type="span", input=...)` → 컨텍스트 매니저. yield된 span에 `.update(output=...)`로 결과 기록.
- ⚠️ `start_as_current_span`은 **없음**(4.12 기준). 문서/블로그에 v3 흔적이 남아 혼동 주의. 전역 클라이언트는 `get_client()`.
- 전송은 비동기 배치(OTEL exporter) → 프로세스 종료 시 flush. 서버 없으면 전송만 실패(span 생성 자체는 됨).

## 배치(사이클) 단위 트레이싱 패턴 (2026-08-03, 관제봇 실전)
- **LLM 관측 도구지만 span은 LLM 없이도 기록된다** → 결정적 배치 단계(수집·분류·발송)도
  span으로 감싸면 "사이클 1건 = 트레이스 1개, 단계 = 자식 span" 타임라인이 나온다.
  단계 결과(건수)는 `span.update(output=...)`로 싣는다.
- ⚠️ **propagate_attributes 중첩 함정**: 트레이스 속성(name·tags)은 trace 단위라, 부모
  트레이스 안에서 자식이 다시 `propagate_attributes`를 부르면 **부모 트레이스의 이름·태그를
  덮어쓴다**. 사이클 트레이스 안에 들어가는 관측은 전부 child 모드(속성 미설정, 관측 이름만)로
  전환해야 한다. — 실측: partners-web-agent judge/tempbot generation 전환.
- **프로세스 싱글턴**: `get_client()`가 전역 1개 → 한 프로세스에 봇이 여럿 동승하면
  init/flush 주체는 하나여야 하고, 초기화 없이 span을 만들면 **조용히 버려진다**(에러 없음).
- 트레이드오프: 개별 콜 트레이스(태그 필터 용이) vs 사이클 트레이스(순서·소요시간 가시).
  전환하면 기존 태그 기반 대시보드 필터가 새 데이터에 안 걸린다 — 전환 공지 필요.

## 스레드 풀 고아 트레이스 (2026-08-04, 관제봇 실전)
- 부모-자식 연결은 OTEL 컨텍스트(=Python [[contextvars]]) 기반 → **스레드 풀 워커에서 연 관측은 부모를 잃고** 태그 없는 관측 1개짜리 고아 트레이스로 이탈한다. 메인 스레드 호출만 정상으로 붙어 부분 이탈이 조용히 진행됨(에러 없음).
- **진단법**: "span이 텅 빔"은 증상일 뿐 원인은 다른 데 있을 수 있다. 부모 트레이스 안 관측 이름 분포와 고아 트레이스 목록을 대조하라 — 실측: 사이클 안 router 27·debate 13·efficiency **0**, efficiency 15건 전부 고아.
- **수정 패턴**: 빌드 시점(부모 트레이스 안) `copy_context()` 캡처 → 호출마다 `ctx.copy().run(...)` (같은 Context 동시 진입 금지). 한계: 부모가 캡처 시점 위치로 고정(중간 span 아래 종속은 디스패치 지점의 태스크별 전파 필요).

## 평가 방법
- **LLM-as-a-Judge** (UI): 서버가 별도 LLM으로 자동 채점 → [[LLM-as-a-Judge]]
- **code/SDK score**: 코드에서 결정적으로 `create_score`.
- **Dataset experiment**: `dataset.run_experiment(task, evaluators)`로 고정셋 일괄 평가.

## 확인 UI
- **Tracing**: trace 트리 + observation 클릭 시 input/output/latency. 리스트 뷰에서 score를 컬럼으로.
- **Scores**: 점수 집계(단, self-hosted v3.178에서 `scores.all` 500 에러 겪음 → 개별 trace의 Scores 탭으로 우회).

출처: langfuse.com/docs (2025~2026), 실제 SDK 4.12.0 inspect 검증.
관련: [[LLM-as-a-Judge]] · [[LLM 응답 검증 전략]]
#stub
