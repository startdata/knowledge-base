---
tags: [Node.js, V8, 메모리, 장애]
---
# Node.js 메모리 오류 3종 — 스택 오버플로우 · V8 힙 부족 · OS OOM #stub

> [[SheetJS 메모리 모델]] · [[대용량 내보내기 메모리 전략]] 와 연결.

## 1. 한눈에 비교

| | 스택 오버플로우 | V8 힙 부족 (heap out of memory) | OS/컨테이너 OOM |
|---|---|---|---|
| 차는 공간 | 콜 스택 (함수 호출 프레임, 기본 약 1MB) | V8 힙 (객체·배열·문자열 등 JS 값) | 프로세스 RSS 전체 (힙 + Buffer + 네이티브 + 코드) |
| 원인 | 끝나지 않는 재귀, 너무 깊은 호출. **데이터 양과 무관** | 살아 있는 객체가 힙 상한 초과. GC가 돌아도 참조가 남아 회수 불가 | 프로세스 전체가 컨테이너 한도·물리 메모리 초과 |
| 증상 | `RangeError: Maximum call stack size exceeded` | `FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory` → `Aborted (core dumped)` | Node 로그에 아무 메시지 없이 사라짐. `OOMKilled: true`, 종료 코드 137 |
| 죽이는 주체 | 없음. JS 예외라 try/catch로 잡히고 프로세스 유지 | **V8이 스스로 abort**. try/catch로 못 잡음 | **OS(커널 OOM killer) 또는 컨테이너 런타임**이 밖에서 kill |
| 해결 | 재귀→반복, 호출 깊이 축소 | 동시에 메모리에 올리는 데이터 축소(스트리밍·청크), `--max-old-space-size` 상향 | 컨테이너 메모리 한도 상향, 프로세스 전체 사용량 축소 |

## 2. 힙 부족 로그 읽는 법
```
Mark-Compact 504.7 (520.2) -> 501.0 (520.7) MB, 1434.03 / 0.00 ms  (average mu = 0.083, current mu = 0.013)
```
- `504.7 -> 501.0 MB`: GC 전후 사용량. 거의 안 줄었다 = 살아 있는 객체가 대부분
- `(520.2)`: 현재 힙 상한 근처의 커밋된 크기
- `1434 ms`: GC 한 번에 1.4초. 힙 상한 근처에서 GC가 반복 실행되며 앱이 거의 멈춤
- `mu` (mutator utilization): 앱 코드가 실제로 실행된 비율. 0.013이면 98.7%가 GC. 이 상태가 지속되면 V8이 "Ineffective mark-compacts"로 판단해 abort

## 3. 힙 상한은 어떻게 정해지나
- `--max-old-space-size=<MiB>`로 명시. 없으면 V8이 **시스템(컨테이너) 가용 메모리를 보고 자동 산정** — 그래서 컨테이너에서는 수백 MB로 낮게 잡히는 경우가 흔하다 (예: 약 520MB)
- 컨테이너 메모리와 cgroup 인식 여부는 Node 버전에 따라 다름 ? (검증 필요)

## 4. 셋의 관계 — 힙 부족을 "해결"하면 OOM이 된다
힙 부족은 V8이 **자기 상한**을 보고 멈추는 것, OOM은 **밖의 한도**로 죽는 것. 힙 상한을 컨테이너 한도보다 크게 잡으면 V8 힙 부족은 사라지고 대신 컨테이너 OOM(137)으로 바뀐다. 따라서 `--max-old-space-size`를 올릴 때는 **컨테이너 메모리 한도를 먼저 확인**하고, 힙 상한은 그보다 여유 있게(Buffer·네이티브 몫을 남기고) 잡는다.

## 5. 진단 순서
1. 에러 문구 확인 — `RangeError`(스택) / `heap out of memory`(V8 힙) / 무메시지+137(OOM)
2. V8 힙이면 어떤 데이터가 동시에 살아 있는지 추적. 단계마다 `process.memoryUsage().heapUsed`를 찍어 행당 비용 측정
3. 데이터 양에 비례해 커지는 구조(전체 누적 후 변환)이면 임계값 폴백·스트리밍으로 구조를 바꾸고, 힙 상향은 보조 수단

## 복습 질문 #flashcards
- 스택 오버플로우와 힙 부족을 구분하는 가장 빠른 기준은? :: 스택은 `RangeError` 예외로 프로세스가 살고, 힙 부족은 `FATAL ERROR ... heap out of memory`로 V8이 abort.
- V8 힙 부족과 OS OOM의 차이는? :: 힙 부족은 V8이 자기 상한을 보고 스스로 멈춤, OOM은 커널/컨테이너가 밖에서 kill(137, 메시지 없음).
- `--max-old-space-size`를 올리기 전에 확인할 것은? :: 컨테이너 메모리 한도. 힙 상한이 한도를 넘으면 힙 부족이 OOM으로 바뀐다.
- GC 로그의 `mu`가 0.01이면? :: 앱 코드 실행 비율 1%. 힙 상한 근처에서 GC만 돌고 있다는 신호.

## 출처
- Node.js CLI `--max-old-space-size`: https://nodejs.org/api/cli.html
- MDN "Maximum call stack size exceeded": https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Errors/Too_much_recursion
- Docker 메모리 제한·OOM: https://docs.docker.com/engine/containers/resource_constraints/
- GC 로그 필드 해석(mu 등)은 세션 정리 — V8 공식 문서 기준 검증 권장
