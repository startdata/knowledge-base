# slavelog 엑셀 다운로드 힙 OOM 분석 (씨드앤 sdn-data-be, 2026-09-14~15)

> 개념: [[Node.js 메모리 오류 3종]] · [[SheetJS 메모리 모델]] · [[대용량 내보내기 메모리 전략]]
> 상태: 분석 완료, 구현 미진행 (`계획:` 대기)

## 문제 · 배경
- sdn-data-be: NestJS + Slack 봇으로 LEAF/CAPS DB 데이터를 엑셀로 내려주는 서비스. 컨테이너(alpine node 20, ECS)에서 `node dist/main`으로 실행, `--max-old-space-size` 미지정
- 매장 "Nguyễn Văn Nghi"(storeId 342, 센서 12개), 기간 2026-08-06 ~ 09-01(27일), 타입 RAW_TEMP(`it`, `ih`, `batt` 포함 12컬럼) 다운로드 중 프로세스 사망
- 로그: 14일 청크 쿼리 2회(각 1.7초, 1.5초 slow) 완료 후 `Mark-Compact 504.7 (520.2) -> 501.0 MB ... mu = 0.013` 반복 → `FATAL ERROR: Ineffective mark-compacts near heap limit ... JavaScript heap out of memory` → `Aborted (core dumped)`
- 사용자의 첫 질문은 "스택 터지는 건가?" → **V8 힙 부족**으로 판별. 근거: 에러 문구가 V8 힙 고유 메시지, `RangeError`가 아님, V8이 스스로 abort

## 원인 (코드 기준, `src/modules/slavelog/slavelog.service.ts`)
1. CSV 전환 기준이 **31일**(`CSV_THRESHOLD_DAYS`)이라 27일은 xlsx 경로
2. xlsx 경로는 `CHUNK_DAYS=14`로 쿼리를 나누지만 결과를 `allRows`에 **전부 누적** — 청크가 DB 부하만 줄이고 메모리는 안 줄임
3. `ExcelService.downloadExcel` → `result.map`(AOA 복제) → `XLSX.utils.aoa_to_sheet`(셀 객체 108만 개) → `XLSX.write`(XML 문자열+zip). 여기서 피크
4. 힙 상한 약 520MB는 컨테이너 메모리 기준 V8 자동 산정값

## 수치
| 항목 | 값 |
|---|---|
| 힙 상한 | 약 520MB (자동) |
| 크래시 행 수 (사용자 재현) | **약 9만 행** × 12컬럼 |
| 추정 행당 비용 | 5~6KB (피크 기준) |
| 청크당 쿼리 시간 | 1.5~1.7초 (14일, 센서 12개) |
| 현재 임계값 | 날짜 31일 (RAW_TEMP), 브랜드 조회는 3일 청크 + 항상 CSV |

## 접근 · 대안 검토
- **행 기준 CSV 폴백이 어렵지 않다고 판단한 근거**: 컨트롤러 `writeResult`가 서비스 반환의 `fileName`/`contentType`을 그대로 쓰므로 서비스 내부에서 형식을 늦게 결정해도 무방. CSV 스트리밍 라이터(`CsvStreamService`)는 이미 존재
- 대안 1 **중간 전환**(권장): 청크 루프에서 `allRows.length` 임계값 초과 시 CSV 라이터 열고 누적분 먼저 기록 후 나머지 스트리밍. 추가 쿼리 없음
- 대안 2 **사전 COUNT**: 단순하지만 slavelog 테이블이 커서 COUNT 비용 우려(청크 쿼리 1.5초 기준)
- 대안 3 RAW_TEMP만 날짜 임계값 7일로 하향: 가장 단순하나 센서 수에 따라 재발
- 보조: `start:prod`에 `--max-old-space-size=2048`. ECS 태스크 메모리 확인 선행 필수(넘으면 힙 부족이 컨테이너 OOM 137로 바뀜)
- **임계값 권장 3만 행** (크래시 9만의 1/3): 동시 다운로드 시 힙 분할, 타입별 컬럼 수 차이, 기존 `MemoryGuardService`와의 정합

## 검증
- 사용자가 기간을 나눠 직접 재현 → 약 9만 행에서 동일 크래시 확인 (행 수와 힙의 비례 확인)
- 행당 정확한 비용은 미측정. 후속: 각 단계 뒤 `process.memoryUsage().heapUsed` 로깅으로 실측 후 임계값 확정

## 다음 단계
- `계획: slavelog xlsx 행 기준 CSV 폴백` 으로 plan.md 작성 → 승인 → 구현
- ECS 태스크 메모리 한도 확인 후 힙 상한 조정 여부 결정
