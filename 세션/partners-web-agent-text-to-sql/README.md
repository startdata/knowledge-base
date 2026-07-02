# partners-web-agent — DB Text-to-SQL 기능 추가

리프 어드민 Slack 챗봇(LangGraph, leaf REST 봇)에 **DB 직접조회(Text-to-SQL)** 기능을 추가하는 작업. (2026-07)

## 문제·배경
- 기존: leaf REST API를 21개 도구로 감싼 LangGraph 봇. 데이터 조회가 REST 경유.
- 목표: 자연어→gemma가 SQL 생성→읽기전용 DB 직접 조회. 동기는 성능/직접성.

## 의도 진화 (시행착오)
1. 처음 "Text-to-SQL을 **완전 별도 모듈**로" → 논의 중 "조회 방식(api/db/혼합) 미정 + 공통 도메인 공유 + 느슨결합"이 진짜 목표로 드러남 → **포트-어댑터**로 재해석. → [[헥사고날 아키텍처]]
2. "도구로? 노드로?" → 사용자 의도는 **DB별 LangGraph 노드**(멀티노드 라우팅 그래프). "도구셋만 교체"로 자꾸 끌고 가다 정정. → [[LangGraph]]
3. "레이어별 4계층 vs 수직 분할" → 냉정 비교 결과 이 규모(~1.8천 줄)엔 **수직 분할 + 공통 domain**이 적합(4계층은 과설계). 내가 헥사고날을 과하게 밀었던 것 인정.

## 주요 결정·설계
- **레이어 재구성**: `slack_agent` 해체 → `src/` 직속 4레이어(`domain/agent/client/infra`). slack은 `client/`의 하나(인터페이스가 앱 루트일 수 없음). import 절대경로, 테스트도 미러링. 로직 무변경, 테스트 그린.
- **DB별 노드 격리**: 각 노드가 자기 DB 스키마·프롬프트만 → gemma 정확도에 유리(schema linking을 그래프 분리로 해결).
- **정보 2계층**: `domain/sql/catalog`=DB 요약+테이블목록(라우팅·계획용) / 노드 `prompt.md`=컬럼 상세(SQL생성용). 라우터/플래너는 요약만, 노드만 상세.
- **프롬프트 .md 텍스트 분리**: 코드와 분리해 튜닝 쉽게. `node.py`가 로드 + `{question}` 치환.
- **확장 뼈대**: 노드 레지스트리(플러그인) + 2단계 라우팅. 노드 늘어도 라우팅 안 붕괴.
- **안전**: 읽기전용 계정 + sqlglot AST guard(SELECT-only·다중문·LIMIT) + `max_execution_time`. → [[Text-to-SQL]]
- **config env 정비**: pydantic-settings라 전 필드 자동 env. `.env.example` 27필드 완비. 고유값(llm_base_url·llm_model·leaf_api_base_url) env 강제(빈 기본값)·사내 IP 플레이스홀더. 튜닝값·상수는 기본값 유지(안전망).

## 결과·검증
- 브랜치 3개 push: `feat/leaf-api-span-tracing`(M2 관측) → `refactor/layer-restructure`(4레이어, main 병합) → `feat/db-text-to-sql`(뼈대+leaf 노드).
- text-to-sql 뼈대(sql_guard·db_client·registry·router·sql_graph·nodes·span) + leaf 노드 골격까지 TDD, 전체 테스트 그린. **기존 leaf 봇 로직 무수정**(뼈대 변경은 base.py schema 인자 제거 1건뿐).
- 진행 상태는 프로젝트 메모리 `text-to-sql-module-progress`에 있음(다음: prompt.md 실제 테이블 채우기 → 조립/CLI → cx/electric).

## 사용한 개념
[[Text-to-SQL]] · [[헥사고날 아키텍처]] · [[LangGraph]] · [[Langfuse]] · [[LLM 응답 검증 전략]]
