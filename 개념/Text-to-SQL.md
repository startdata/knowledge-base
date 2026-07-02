# Text-to-SQL

자연어 질의를 LLM이 **SQL로 변환**해 DB를 직접 조회하는 방식. 중간 API 계층 없이 직접성·유연성을 얻지만, LLM이 생성한 SQL의 안전·정확도가 핵심 리스크.

## 안전장치 (필수 → 권장 순)
1. **읽기 전용 DB 계정 (1차 방어, 최우선)**: `GRANT SELECT`만. LLM이 DROP/DELETE를 생성해도 권한으로 차단. 애플리케이션 필터만 의존하는 건 금지.
2. **생성 SQL 검증 (AST 기반)**: SELECT-only 판별, 다중문(`;`) 차단, DDL/DML 키워드 거부.
   - ⚠️ **정규식 필터는 뚫린다**: 주석(`/* SELECT */ DELETE`)·URL 인코딩(`%3B`)·대소문자(`UnIoN`)로 우회. **AST 파싱(sqlglot)** 은 코드 형태가 아니라 **의미(문장 종류)** 를 보므로 우회 불가.
3. **LIMIT 자동 주입** + **statement timeout**(MySQL `max_execution_time` 세션변수, SELECT 전용): 대량 노출·무한 쿼리 방지.
4. LLM SQL의 위험은 전통적 injection보다 **hallucination/독성 생성**(ToxicSQL) → output 필터 병행.

## 정확도 — 벤치마크
- Execution Accuracy(생성 SQL 실행 결과가 정답과 같은지)로 측정. 벤치마크: **Spider**(깔끔), **BIRD**(실데이터·결측·값조건 — 실무에 가까움, 더 어려움).
- **Gemma 3 27B ≈ Spider 75.7% / BIRD 52.4%** (오픈소스 최상위이나 GPT-4 대비 BIRD 23%p 격차). 소형 오픈모델은 복잡 조인·중첩·값기반 조건에서 취약.

## 정확도 향상 (복합 — 하나로는 부족, 겹쳐야 함)
- **스키마 메타 강화**(컬럼 설명·예시값·**enum 코드값·외래키**) +3~8%. enum·FK는 DB 스키마만 봐선 모름 → 사람이 글로 남겨야 LLM이 WHERE/JOIN을 맞춤.
- **schema linking**(관련 테이블만 주입): 전체 주입은 토큰·정확도 하락. DB/도메인별로 격리하면 자연 해결.
- **few-shot**(질의→SQL 예시) +3~10%.
- **self-correction**(실행 오류/0행 → 오류+스키마 재입력 재시도, ≤3회) +5~15%.

## 라이브러리 (Python)
- 드라이버: **PyMySQL**(순수 파이썬, 읽기전용 조회에 충분).
- 검증: **sqlglot**(AST·방언인식, `parse`로 다중문·`isinstance(ast, exp.Select)`·`.limit(n)`).

관련: [[LangGraph]](DB별 노드로 격리) · [[LLM 응답 검증 전략]](4단계 검증) · [[Langfuse]](생성 SQL 관측)
#stub
