# LLM-as-a-Judge

LLM으로 다른 LLM의 출력을 **자동 채점**하는 평가 방법. 사람 라벨 없이 주관적 품질(정확성·도움됨·근거성 등)을 점수화한다.

## 구성 (Langfuse UI 기준)
1. **평가용 LLM 연결**: judge가 쓸 모델 등록. structured output(JSON/tool calling) 지원 필수 → GPT-4o/Claude 급 권장.
2. **평가 프롬프트**: 평가 기준 + `{{input}}`/`{{output}}`/`{{expected_output}}` 변수.
3. **변수 매핑**: 변수를 trace 데이터(Input/Output/metadata, JSONPath)에 연결. Live Preview로 확인.
4. **Score 타입**: NUMERIC(0~1)/CATEGORICAL/BOOLEAN.
5. **reasoning / output prompt**: 이유(comment)를 어떻게 쓸지 + 점수 형식. **기본 영어 → 한국어로 바꿔야 comment가 한국어**. output 형식이 Score 타입과 어긋나면 점수가 깨짐(예: BOOLEAN에 "0~1 숫자" 지시).
6. **실행 대상**: 신규 trace 자동 / 필터 / 샘플링.

## 한계 (중요)
- **비결정적**: 같은 입력도 점수가 흔들림.
- **structured output 의존**: judge 모델이 형식을 못 내면 score가 비거나 0으로 떨어짐. (자체 소형 vLLM을 judge로 쓸 때 리스크)
- **정답이 있는 검증엔 부적합**: 파라미터/도구선택처럼 정답이 명확한 건 코드 비교가 정확 → [[LLM 응답 검증 전략]]
- **observation 단위로 돌면 노이즈**: 에이전트 중간 단계(도구호출용 LLM)까지 채점돼 0점이 섞임. trace-level 또는 최종 답변만으로 좁히는 게 좋음.

## comment(총평) 확인
- 점수 옆 말풍선/Scores 탭에서 judge가 쓴 reasoning을 봄. 비어 있으면 judge 모델이 형식을 못 낸 것.

출처: langfuse.com/docs LLM-as-a-Judge.
관련: [[Langfuse]] · [[LLM 응답 검증 전략]]
#stub
