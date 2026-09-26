# AWS 알림 파이프라인 (SNS → Chatbot → Slack)

AWS에서 생긴 경보·이벤트를 Slack으로 받는 표준 경로.

```
CloudWatch 경보 ─┐
EventBridge 규칙 ─┼─▶ SNS 토픽 ─▶ Amazon Q Developer in chat applications(구 AWS Chatbot) ─▶ Slack 채널
```

## 구성 요소
| 요소 | 역할 | 주의 |
|---|---|---|
| SNS 토픽 | 알림을 모으는 우편함 | **리전별 리소스**. 경보와 같은 리전에 있어야 한다 |
| Chatbot | SNS 메시지를 Slack 형식으로 보여줌 | 한 채널 구성에 **여러 리전의 토픽**을 연결할 수 있다 |
| Slack 채널 | 받는 곳 | 비공개 채널이면 앱 초대 필요 (`/invite @Amazon Q`) |

## 리전이 둘로 갈리는 경우
- [[Route 53 상태 검사]] 경보는 us-east-1 고정, RDS·EC2 경보는 리소스가 있는 리전(예: 서울).
- → SNS 토픽을 **리전마다 하나씩** 만들고, Chatbot 채널 구성에 **둘 다** 연결한다. 받는 쪽에서는 차이가 없다.
- Chatbot의 "테스트 메시지 보내기"는 연결된 토픽마다 메시지를 보낸다 → 두 개가 오면 둘 다 연결된 것.

## 권한 — 최소로
- Chatbot IAM 역할 정책 템플릿: 알림만 받을 거면 **"알림 권한"**만. "Amazon Q Developer 액세스 권한"은 Slack에서 AWS 정보를 조회하는 통로라 불필요하면 뺀다.
- 채널 가드레일: `ReadOnlyAccess` 등으로 채널에서 가능한 작업의 상한을 둔다.
- 나중에 Slack 버튼으로 명령(재시작 등)을 실행하려면 그때 권한을 추가한다.

## RDS 이벤트는 EventBridge를 거친다
- RDS "이벤트 구독"을 SNS에 직접 연결하면 Chatbot이 메시지를 제대로 표시하지 못할 수 있다(확실하지 않음 ?).
- EventBridge 규칙(`source: aws.rds`, `detail-type: RDS DB Instance Event`, `detail.EventCategories`로 필터) → SNS가 더 안전하다.
- 배열 필드(`EventCategories`)에 값 목록을 걸면 **하나라도 겹치면** 일치한다.
- 실제 이벤트 없이 패턴만 확인: EventBridge **샌드박스**에서 샘플 이벤트로 패턴 테스트.
- AWS 서비스 이벤트를 기본 이벤트 버스로 받는 비용은 무료(요금표는 "AWS management events"를 무료로 명시. RDS 이벤트도 같다고 이해 — 검증 필요 ?).

## Slack으로 보내는 다른 길: Incoming Webhook
앱 코드에서 직접 보낼 때는 Chatbot이 아니라 Slack **Incoming Webhook**을 쓴다.
- Slack 앱을 manifest로 만들 때 `oauth_config.scopes.bot: [incoming-webhook]`을 넣으면 **`features.bot_user`도 정의해야** 한다("require bot user" 에러).
- 응답 `no_service` = Webhook URL이 잘렸거나 무효(삭제·재발급됨).
- Webhook URL은 그 자체가 비밀번호다. 레포·채팅에 올리지 않는다.

## 관련
[[CloudWatch 경보]] · [[Route 53 상태 검사]] · [[에러 알림 설계]]

#flashcards
- Q: Route 53 경보와 RDS 경보를 같은 Slack 채널로 받으려면 SNS 토픽이 몇 개 필요한가? → A: 리전별 1개씩(us-east-1, 서울) 2개를 한 Chatbot 채널에 연결.
- Q: Slack manifest의 "requires bot user" 에러 원인? → A: bot scope(incoming-webhook)를 넣었는데 features.bot_user가 없음.

## 출처
- [AWS Chatbot (Amazon Q Developer in chat applications) 관리자 가이드](https://docs.aws.amazon.com/chatbot/latest/adminguide/what-is.html) — URL 검증 필요
- [Amazon RDS events in EventBridge](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-cloud-watch-events.html) — URL 검증 필요
- [EventBridge Pricing](https://aws.amazon.com/eventbridge/pricing/)
- [Slack — Sending messages using incoming webhooks](https://api.slack.com/messaging/webhooks)

#stub
