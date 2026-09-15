---
tags: [오픈소스, 청구, 구독]
---
# Kill Bill #stub

> [[구독 청구 도메인 모델]] · [[모듈러 모놀리스]] 와 연결.

미국 The Billing Project의 오픈소스(Apache 2.0) 구독·청구·결제 플랫폼. Java, MySQL/PostgreSQL.
- **Account / Subscription / Invoice / Payment / Entitlement**가 서브시스템으로 나뉜다. 특히 Billing(재정)과 Entitlement(서비스 접근, BlockingState CLEAR/BLOCK/SUSPEND)의 분리가 참고 가치.
- PSP는 플러그인(Stripe·Adyen·Braintree 등). 모든 상태 변경을 이벤트로 외부에 내보낸다.
- 단일 배포 단위(코어 + 플러그인)다. "서비스 분리" 사례가 아니라 "한 프로세스 안의 경계" 사례.
- 도입하지 않은 이유: 한국 결제수단(빌링키·CMS·가상계좌·세금계산서) 플러그인이 조사 자료에서 확인되지 않아 플러그인 작성량이 자체 구현과 비슷, 팀 스택과 다른 시스템 운영, 모듈별 배치 자유도 감소. 결제 실패 → 차단 규칙도 플러그인으로 작성해야 한다.
- ? 수동 재시도 API 존재 여부는 조사 자료에 없음.

출처: [docs.killbill.io](https://docs.killbill.io/), [Entitlement](https://docs.killbill.io/latest/entitlement_subsystem), [아키텍처 블로그](https://blog.killbill.io/blog/kill-bill-billing-system-architecture/), [GitHub](https://github.com/killbill/killbill)
