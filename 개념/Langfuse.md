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
