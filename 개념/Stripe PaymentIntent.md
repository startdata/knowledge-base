---
tags: [Stripe, 결제, 객체모델]
---
# Stripe PaymentIntent #stub

> [[결제 상태 기계]] · [[멱등성]] · [[구독 청구 도메인 모델]] 와 연결.

Stripe 결제의 중심 객체. 하나의 결제 의도를 추적하며 상태 기계를 갖는다.
- 상태: `requires_payment_method → requires_confirmation → requires_action(3DS) → processing → requires_capture → succeeded / canceled`
- **PaymentIntent 하나에 Charge(실제 시도)가 여러 개** 붙을 수 있다 → "결제 1 : 시도 N" 모델의 원형.
- Refund는 Charge/PaymentIntent를 참조하고 여러 건(부분 환불), Dispute는 분쟁, BalanceTransaction은 잔액 변동(수수료·순액) 기록.
- 멱등키는 `Idempotency-Key` 헤더, 계정·엔드포인트 범위, 같은 키면 원 응답 반환.
- 승인·매입 분리(`requires_capture`)는 해외 카드망 특성. 국내 빌링키 결제에는 대응 상태가 없다.
- Billing(Subscription·Invoice·Coupon)은 별도 제품 계층이며 결제 코어에는 쿠폰 개념이 없다 → "할인은 결제 코어 바깥".

출처: [PaymentIntent](https://docs.stripe.com/payments/payment-intents), [Refund](https://docs.stripe.com/api/refunds/object), [Idempotency](https://stripe.com/blog/idempotency). BalanceTransaction 세부는 공식 문서 재확인 필요.
