# Route 53 상태 검사 (Health Checks)

AWS의 여러 지역에서 엔드포인트(URL)를 주기적으로 호출해 정상 여부를 판단하는 기능. 원래 목적은 DNS 장애 조치(failover)지만, CloudWatch 경보와 묶어 **외부 헬스체크 모니터**로도 쓴다.

## 리전 구조 — 가장 헷갈리는 부분
| 구성 요소 | 리전 |
|---|---|
| 상태 검사 설정 | **글로벌** (콘솔 리전 표시가 "글로벌") |
| 검사하는 지역 | 선택. 가능한 값: `us-east-1, us-west-1, us-west-2, eu-west-1, ap-southeast-1(싱가포르), ap-southeast-2(시드니), ap-northeast-1(도쿄), sa-east-1` — **서울 없음**, **최소 3개** |
| 지표(`HealthCheckStatus` 등) | **us-east-1(버지니아)의 CloudWatch에만** 기록 |
| 경보·SNS 토픽 | 따라서 **us-east-1에 만들어야** 함 |

- 검사 지역과 지표 리전은 무관하다. 도쿄·싱가포르에서 검사해도 결과는 버지니아에 쌓인다.
- 서버가 서울에 있으면 가까운 아시아 3곳을 고르는 게 좋고, 서울 리전 장애도 밖에서 감지된다.
- 새 콘솔은 상태 검사 생성 화면에 알림 설정이 없어서, CloudWatch(us-east-1)에서 경보를 따로 만든다.

## 판정 규칙
- HTTP/HTTPS: **2xx 또는 3xx면 정상.**
- ⚠️ **함정**: nginx가 HTTP(80)를 HTTPS로 301 리다이렉트하면, HTTP 검사는 앱이 죽어도 항상 정상이다. **HTTPS로 검사해야 한다.**
- HTTPS 검사는 엔드포인트가 TLS 1.0~1.2를 지원해야 한다.
- 실패 임계값(기본 3): 연속 N번 실패해야 상태를 바꾼다.
- 여러 지역 검사 결과를 종합해 판단한다. 문서상 정상으로 보고하는 검사 서버가 18% 미만이면 비정상.

## 호출 빈도 — 생각보다 많다
- 요청 간격(표준 30초, 빠름 10초)은 **검사 서버 하나하나의 간격**이다. 지역마다 서버가 여러 대이고 서로 조율하지 않는다.
- 문서 기준으로 전체 지역을 쓰면 엔드포인트는 **평균 2초에 1번꼴**로 요청을 받는다. 지역 3개로 줄여도 분당 수십 건 수준이다.
- 그래서 헬스체크 경로는 가볍게 만들고, 요청 로그에서 빼고, DB 대기 시간을 짧게 둔다. → [[헬스체크 설계]]

## 요금 (2026-09 요금표)
| 항목 | AWS 엔드포인트 | AWS 외 엔드포인트 |
|---|---|---|
| 기본 검사 | $0.50/월 (같은 계정 리소스 **50개까지 무료**) | $0.75/월 |
| 옵션 1개당 (HTTPS, 문자열 일치, 빠른 간격, 지연 측정) | $1.00/월 | $2.00/월 |
- HTTPS 검사 1개면 대략 월 $1. 무료 한도가 옵션에도 적용되는지는 요금표에 명확하지 않다(?).

## 대안 비교
| 방법 | 장점 | 단점 |
|---|---|---|
| Route 53 상태 검사 | 코드 없음, 다지역, AWS 안에서 관리 | 경보가 us-east-1, 호출 많음 |
| EventBridge 스케줄 + Lambda | 한 리전에서 관리, 호출 빈도 조절 | 코드 관리, 같은 리전 장애에 취약 |
| 외부 SaaS (UptimeRobot 등) | 가입만 하면 끝 | AWS 밖, 무료 플랜 주기 김 |
| CloudWatch Synthetics | 시나리오 테스트 가능 | 헬스체크 하나에는 비쌈 |

## 관련
[[헬스체크 설계]] · [[CloudWatch 경보]] · [[AWS 알림 파이프라인]]

#flashcards
- Q: Route 53 상태 검사 경보를 서울 리전에서 못 만드는 이유? → A: 지표가 us-east-1 CloudWatch에만 기록되기 때문.
- Q: HTTP로 헬스체크하면 앱이 죽어도 정상으로 나오는 경우? → A: nginx가 HTTPS로 3xx 리다이렉트할 때(3xx도 정상 판정).
- Q: 요청 간격 30초면 엔드포인트는 30초에 1번 호출되나? → A: 아니다. 검사 서버마다 30초라 실제로는 훨씬 잦다.

## 출처
- [Values that you specify when you create or update health checks](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/health-checks-creating-values.html)
- [Monitoring health checks using CloudWatch](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/monitoring-health-checks.html)
- [HealthCheckConfig — API Reference (Regions 유효값)](https://docs.aws.amazon.com/Route53/latest/APIReference/API_HealthCheckConfig.html)
- [Route 53 Pricing](https://aws.amazon.com/route53/pricing/)

#stub
