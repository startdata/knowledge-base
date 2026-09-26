# NestJS `@Res({ passthrough: true })`

컨트롤러에서 응답 객체(Express `Response`)를 직접 받으면서도, **반환값 처리는 Nest에 맡기는** 방식.

## 두 모드
| 방식 | 응답 전송 | 인터셉터·직렬화 |
|---|---|---|
| `@Res()` | 개발자가 `res.json()`으로 직접 보내야 함 | 반환값을 Nest가 처리하지 않음 |
| `@Res({ passthrough: true })` | 반환값을 Nest가 보냄 | 인터셉터 등 정상 동작 |

→ 쿠키·헤더·**상태 코드만 바꾸고** 나머지는 평소처럼 쓸 때 passthrough를 쓴다.

## 상태 코드를 동적으로 바꾸기
```ts
@Get()
async healthCheck(@Res({ passthrough: true }) response: Response) {
  if (!isDbUp) response.status(HttpStatus.SERVICE_UNAVAILABLE);
  return { db: isDbUp ? 'up' : 'down' };
}
```
- `@HttpCode()`는 정적이라 조건별 상태 코드는 이 방식이나 예외로 처리한다.
- 예외를 던지면 예외 필터를 탄다(로그·알림이 따라옴). 상태 코드만 바꾸고 싶으면 이 방식. → [[헬스체크 설계]]
- 응답 래핑 인터셉터가 `response.statusCode`를 읽으면, 핸들러가 반환하기 전에 바꿨으므로 본문에도 바뀐 코드가 들어간다.

## ⚠️ 버전 의존성
- Nest `master` 소스(`router-execution-context.ts`)를 보면 응답 시 `reply(res, result, httpStatusCode)`로 **라우트 기본 상태 코드를 다시 넘기는 경로**가 있어, 덮어쓸 여지가 보인다.
- 그러나 **11.0.12**에서 실제 앱(URI 버저닝 + 응답 래핑 인터셉터)을 띄워 확인하니 503이 유지됐다.
- → 버전을 올릴 때 동작이 바뀔 수 있으니, **실제 HTTP로 상태 코드를 확인하는 통합 테스트(supertest)**로 회귀를 막는다. 컨트롤러 메서드 직접 호출 단위 테스트로는 이 문제를 못 잡는다.

## 관련: 미들웨어 exclude와 URI 버저닝
`MiddlewareConsumer.exclude()`와 URI 버저닝(`/v1/...`) 조합은 버전별 동작 변경 이슈가 있었다(nestjs/nest#11442). 확실하게 하려면 미들웨어 안에서 경로를 직접 비교한다.

## 관련
[[헬스체크 설계]]

#flashcards
- Q: `@Res()`와 `@Res({ passthrough: true })`의 차이? → A: 전자는 직접 응답을 보내야 하고 반환값·인터셉터 무시, 후자는 반환값을 Nest가 처리.
- Q: passthrough로 바꾼 상태 코드의 회귀를 막는 테스트? → A: supertest로 실제 HTTP 상태를 확인하는 통합 테스트.

## 출처
- [NestJS Docs — Controllers (Library-specific approach)](https://docs.nestjs.com/controllers#library-specific-approach)
- [nestjs/nest — router-execution-context.ts](https://github.com/nestjs/nest/blob/master/packages/core/router/router-execution-context.ts)
- [nestjs/nest — express-adapter.ts (reply)](https://github.com/nestjs/nest/blob/master/packages/platform-express/adapters/express-adapter.ts)
- [nestjs/nest#11442 — middleware exclude 동작 변경](https://github.com/nestjs/nest/issues/11442)

#stub
