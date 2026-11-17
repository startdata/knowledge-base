---
tags: [NestJS, Swagger, 파이프, 동적모듈]
---
# NestJS 실무 함정

NestJS로 기능을 붙이다 실제로 시험이 깨지거나 문서가 조용히 틀어진 특성 모음. (@nestjs/common 9.4, @nestjs/swagger 6.3 기준)

> [[NestJS Res passthrough]] · [[모듈러 모놀리스]] 와 연결.

## 1. env로 라우트를 켜고 끄기 — 동적 모듈 `register()`

**원리**
- 정적 메서드가 `DynamicModule`을 돌려주게 만든다. 이름은 관례상 `register()`·`forRoot()`·`forFeature()`다.
- 돌려준 메타데이터는 `@Module()`에 적은 것을 **덮어쓰지 않고 더한다**("extends the metadata in the `@Module()` decorator").
  - 그래서 `@Module({ controllers: [A] })`에 `register()`가 조건을 만족할 때만 `{ module, controllers: [B], providers: [...] }`를 돌려주면 A+B가 된다.
  - 조건이 아니면 `{ module }`만 돌려주면 된다. 정적 모듈과 똑같다.
- 라우트를 아예 만들지 않으면 Swagger 문서에도 나오지 않는다. 가드에서 404를 던지는 방식은 라우트와 문서가 남는다.

**함정**
- `register()`는 그 모듈을 import하는 쪽의 `imports` 배열이 평가될 때 불린다. 그 순간은 DI가 없어 `ConfigService`를 쓸 수 없고 `process.env`를 직접 읽는다.
  - `.env`를 쓰는 앱이면 `imports` 배열에서 `ConfigModule.forRoot()` 뒤에 둔다(배열은 앞에서부터 평가된다).
  - 위 두 줄은 현재 이해다. 공식 문서에 직접 설명은 없다. 같은 문제를 `@nestjs/config`의 `ConditionalModule.registerWhen()`은 `ConfigModule.envVariablesLoaded` 훅을 기다리는 방식으로 푼다(기본 5초 시간 상한).
- 모듈 파일 최상위에 `@Module({ controllers: cond ? [...] : [] })`처럼 쓰면 파일을 import할 때 **한 번만** 평가된다. 시험에서 env를 바꿔 가며 확인할 수 없다. 부를 때마다 평가하는 `register()`가 시험하기 쉽다.

## 2. 전역 `ValidationPipe`(transform)가 파라미터 파이프보다 먼저 돈다

**순서** (공식 요청 생명주기)
- 미들웨어 → 가드 → 인터셉터 → 파이프 → 핸들러 순서다.
  - 그래서 토큰 가드의 401이 본문·경로 검증의 400보다 먼저 나온다.
- 파이프는 전역 → 컨트롤러 → 라우트 → **라우트 파라미터** 순서다.

**함정**
- `ValidationPipe({ transform: true })`는 원시 타입도 바꾼다. "Path parameters and query parameters always arrive as strings… `ValidationPipe` converts the string identifier to a number."
- 그래서 `@Query('userId', MyPipe) userId: number`에서 `MyPipe`는 `'42'`가 아니라 **이미 숫자 `42`**를 받을 수 있다.
  - "문자열이면 정규식 검사"처럼 짠 파이프는 정상 값까지 모두 400으로 거절한다.
- 직접 짜는 파라미터 파이프는 숫자로 들어와도 정수·범위를 검사하게 만든다.
  - 내장 `ParseIntPipe`는 원래 `string`·`number`를 둘 다 받는다(`isNumeric`). 그래서 이 문제를 겪지 않는다.

## 3. Swagger 문서는 `include`에 적은 모듈만 담는다

- `SwaggerModule.createDocument(app, config, { include: [모듈들] })`은 적은 모듈의 컨트롤러만 문서에 싣는다.
  - 새 모듈을 만들고 `include`에 넣지 않으면 **API는 동작하는데 Swagger에는 안 보인다.**
- `include`에 있는데 앱에 실리지 않은 모듈(조건부로 빠진 동적 모듈 등)은 오류 없이 문서에서만 빠진다. (직접 시험으로 확인)
- **DTO 스키마 이름은 클래스 이름이다.**
  - 6.3 소스 `schema-object-factory.js`에 `schemas[type.name] = typeDefinition`이 있다. 다른 모듈에 같은 이름의 DTO 클래스가 있으면 나중에 탐색된 것이 **조용히 덮어쓴다.**
  - 두 API가 같은 `$ref`를 가리키게 되어 한쪽 문서가 틀어진다.
  - 모듈을 `include`에 더할 때 DTO 클래스 이름이 겹치는지 확인한다.
- **`ApiQuery`가 붙는 대상은 버전마다 다르다.**
  - 6.3.0 타입 정의는 `MethodDecorator`뿐이라 메서드마다 붙여야 한다.
  - master 소스는 `MethodDecorator & ClassDecorator`다.
  - `ApiHeader`는 6.3.0에서도 클래스·메서드 둘 다 된다.

관련: [[NestJS Res passthrough]] · [[모듈러 모놀리스]]

출처
- 동적 모듈: https://docs.nestjs.com/fundamentals/dynamic-modules
- 요청 생명주기(가드·파이프 순서): https://docs.nestjs.com/faq/request-lifecycle
- ValidationPipe 원시 타입 변환: https://docs.nestjs.com/techniques/validation (Transform payload objects)
- ConditionalModule: https://docs.nestjs.com/techniques/configuration (Conditional module configuration)
- Swagger `include`: https://docs.nestjs.com/openapi/other-features (Multiple specifications)
- 스키마 키: `@nestjs/swagger` 6.3.0 `dist/services/schema-object-factory.js` `exploreModelSchema`
- `ApiQuery` 시그니처: 6.3.0 `dist/decorators/api-query.decorator.d.ts`, master https://github.com/nestjs/swagger/blob/master/lib/decorators/api-query.decorator.ts
- `ParseIntPipe.isNumeric`: `@nestjs/common` 9.4.3 `pipes/parse-int.pipe.js`
- 실측: leaf 결제 개편(개발 시험 전용 API, 결제 API Swagger 노출) 시험

#stub
