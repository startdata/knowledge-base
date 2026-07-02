# LangGraph

LLM 에이전트를 **상태 그래프**(노드=처리 단계, 엣지=흐름)로 구성하는 프레임워크. 상태(State)를 노드들이 갱신하며 흐른다.

## 핵심
- **StateGraph(State)**: State는 TypedDict. 여러 노드가 같은 키를 갱신하면 **리듀서**로 병합 — 예: `Annotated[list, add]`(append 누적).
- **노드**: `state → dict(부분 상태)` 함수. `add_node(name, fn)`.
- **엣지**: `add_edge`(고정), `add_conditional_edges(src, 라우팅함수, {값: 목적지})`(분기). `set_entry_point`, `END`.
- **compile(checkpointer=...)**: 체크포인터로 대화 상태 지속(thread_id별).
- **도구 실행**: `ToolNode`가 LLM의 tool_calls를 실행. agent⇄tool 루프가 ReAct 패턴.

## 멀티노드 라우팅 (여러 데이터소스/전문 노드)
- 데이터베이스/도메인마다 **별도 노드**를 두고 `router`가 대상 노드로 분기 → 각 노드가 자기 컨텍스트만 다룸.
- **격리의 이점**: 각 노드가 자기 스키마·프롬프트만 봄 → LLM이 한 번에 전체를 안 봐도 됨 → **정확도↑ + 토큰↓**. (Text-to-SQL에서 DB별 노드 = schema linking을 그래프 분리로 해결)

## 확장 패턴 (노드가 많아질 때)
- **노드 레지스트리(플러그인)**: 노드가 자신을 `register(NodeSpec)` → 그래프는 `all_nodes()`로 조립. **노드 추가 시 그래프 코드 불변**(Open-Closed). 하드코딩 `if/elif` 나열은 노드 10개쯤에서 라우팅이 붕괴.
- **2단계 라우팅**: 노드 전부를 LLM에 주지 말고 **① 후보 선별(키워드/임베딩) → ② 소수 후보만 LLM 판단**. 노드 100개여도 LLM 부담 일정.
- 라우팅 정보는 **요약(노드 description)** 으로 충분 — 상세 스키마는 선택된 노드만.

## 관측
- `langfuse.langchain.CallbackHandler`를 invoke config의 callbacks로 주입 → 노드·LLM·도구 실행이 trace로. → [[Langfuse]]

관련: [[헥사고날 아키텍처]](도구=포트) · [[Text-to-SQL]] · [[Langfuse]]
#stub
