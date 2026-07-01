# partners-web-agent — Langfuse 트레이싱 개선 + 응답 검증

리프 어드민 데이터 조회 Slack 챗봇(LangGraph, agent⇄tool 구조)의 관측·검증 강화 작업. (2026-06~07)

## 문제·배경
- 기존: Langfuse `CallbackHandler`만 붙어 trace는 쌓이나 **메타(session/user/이름)가 없고**, 도구가 실제 어떤 leaf API를 어떤 파라미터로 쳤는지 trace에 안 보임(leaf_client가 도구 함수 내부 httpx로 직접 호출).
- 목표: ① trace를 사용자 친화적으로(session/user) ② 응답을 **트레이싱 기반으로 검증**.

## 검증 방향 결정 (시행착오)
- 처음 UI LLM-as-judge(groundedness/helpfulness)로 시작. 자체 vLLM(gemma4:26b)을 judge로 써도 comment(총평)는 한국어로 잘 나옴.
- 단 **점수 노이즈** 발견: observation 단위로 평가가 돌아 도구호출용 중간 LLM(답변 텍스트 없음)까지 채점돼 groundedness 0.00이 섞임.
- 사용자가 **4단계 검증**(①파라미터 ②도구선택 ③API호출 ④요약) 요구 → 정답이 명확한 ①②③은 **코드 비교(오프라인 dataset)**, ④만 LLM judge로 결론. → [[LLM 응답 검증 전략]]
- dataset은 **YAML 외부 파일**로 두어 코드 수정 없이 케이스 편집.
- 추가 UI judge 평가자: 주관적인 것(완전성·간결성·안전성)은 judge, 결정적인 것(거부 적절성·슬랙 서식·제어토큰 누출)은 코드로 구분.

## 마일스톤
- **M1** 메타 주입(session/user, `propagate_attributes`) — 미착수(가벼운 부가가치)
- **M2 leaf_client span — 완료**
- **M3** dataset 4단계 검증 하니스 — 미착수(핵심). graph 빌드 팩터리 추출 + YAML 로더 + evaluator + `run_experiment`. leaf 실호출/모킹 미결.

## M2 구현 내용
- leaf API 호출을 `client.start_as_current_observation(name="leaf GET {path}", as_type="span", input=params)`로 감싸 **path/params/status를 trace에 노출** → 검증 ③의 전제.
- 고객 PII 파라미터(customerName/customerPhone/phone/email) 마스킹. 매장명·검색어는 유지.
- langfuse 키 없으면 no-op(span_factory=None → LeafClient 내장 no-op). 기존 동작 불변.
- `observability`를 단일 파일 → 서브패키지(`handler.py`/`leaf_span.py`, `__init__` re-export)로 분리.

## 결과·검증
- M2: 테스트 16개 + 전체 회귀 통과. `feat/leaf-api-span-tracing` 브랜치 push.
- **버그 잡음(핵심 교훈)**: 처음 web 문서 기반으로 `start_as_current_span` 사용 → langfuse **4.12에 없는 메서드**. 실제 SDK `inspect` + 실클라이언트 스모크로 발견해 `start_as_current_observation(as_type="span")`으로 수정. **FakeClient 목(mock) 테스트만으론 못 잡음** → 실제 API 시그니처는 실물로 확인해야 함.
- 인프라 이슈: self-hosted langfuse v3.178.0 OSS의 Scores 페이지 500 에러(`scores.all`) → 개별 trace Scores 탭으로 우회.
- 환경: 봇의 실제 langfuse 키는 배포 환경에 있고 로컬 클론 `.env`엔 없음 → 로컬에서 실전송 스모크 불가, 실물 확인은 배포 후.

## 사용한 개념
[[Langfuse]] · [[LLM-as-a-Judge]] · [[LLM 응답 검증 전략]]
