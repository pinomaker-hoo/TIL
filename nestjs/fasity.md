# Fastify와 NestJS 연동 가이드

## 개요

Fastify는 Node.js를 위한 고성능 웹 프레임워크로, 낮은 오버헤드, 강력한 플러그인 시스템, 스키마 기반의 유효성 검사(AJV), 뛰어난 로깅(pino)과 확장성을 제공합니다. NestJS는 기본적으로 Express를 사용하지만, `@nestjs/platform-fastify` 어댑터를 통해 Fastify를 서버 런타임으로 사용할 수 있습니다.

이 문서는 Fastify의 핵심 개념과 기능을 정리하고, NestJS에서 Fastify를 적용하는 방법과 실전 팁을 상세히 설명합니다.

## Fastify 핵심 특징

- 고성능/저오버헤드: 비동기 처리 최적화, 라우팅/직렬화 성능 우수
- 스키마 기반 개발: JSON Schema로 요청/응답 검증 및 직렬화
- 강력한 플러그인 아키텍처: 캡슐화와 재사용성
- 내장 로깅: pino 기반 초고속 구조적 로깅
- 타입 친화적: TypeScript에 우호적(공식 타입 제공)

## Fastify 주요 개념

- 플러그인(Plugin): 기능 단위를 모듈화하여 등록 (`fastify.register(plugin, options)`)
- 훅(Hook): 요청/응답 라이프사이클 중간 지점에 로직 삽입 (`onRequest`, `preHandler`, `onSend`, `onResponse` 등)
- 데코레이터(Decorator): Fastify 인스턴스/요청/응답 객체에 커스텀 속성/메서드 주입
- 스키마(Schema): `body`, `querystring`, `params`, `headers`, `response`에 대한 JSON Schema 정의
- 직렬화(Serializer): 응답 직렬화 최적화(스키마 기반)

## 자주 사용하는 Fastify 플러그인

- `@fastify/cors`: CORS 설정
- `@fastify/helmet`: 보안 헤더
- `@fastify/compress`: 응답 압축(gzip/br)
- `@fastify/cookie`: 쿠키 파서/서명
- `@fastify/session`: 세션 관리(쿠키 기반)
- `@fastify/multipart`: 파일 업로드
- `@fastify/static`: 정적 파일 제공
- `@fastify/websocket`: 웹소켓 지원

## NestJS에서 Fastify 사용하기

### 설치

```bash
npm i @nestjs/platform-fastify fastify @fastify/cors @fastify/helmet @fastify/compress @fastify/cookie
# 선택: 파일업로드/정적/세션/웹소켓
npm i @fastify/multipart @fastify/static @fastify/session @fastify/websocket
```

### 부트스트랩: FastifyAdapter

```ts
// src/main.ts
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import fastifyCookie from '@fastify/cookie';
import fastifyCors from '@fastify/cors';
import fastifyHelmet from '@fastify/helmet';
import fastifyCompress from '@fastify/compress';

async function bootstrap() {
  const adapter = new FastifyAdapter({
    logger: true, // pino 로거 활성화
    // trustProxy: true, // 프록시 사용 시
  });

  const app = await NestFactory.create<NestFastifyApplication>(AppModule, adapter, {
    // bodyParser: true // (기본값) Nest 파이프 사용 시 일반적으로 유지
  });

  // Fastify 플러그인 등록 (Nest 레벨이 아닌 Fastify 인스턴스 레벨)
  await app.register(fastifyCors, { origin: true, credentials: true });
  await app.register(fastifyHelmet);
  await app.register(fastifyCompress, { global: true });
  await app.register(fastifyCookie, {
    secret: process.env.COOKIE_SECRET || 'dev-secret', // 서명 쿠키 사용 시
  });

  // 전역 파이프/필터/인터셉터 (Nest 방식)
  // app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  await app.listen(3000, '0.0.0.0');
}
bootstrap();
```

### 요청/응답 객체 타입

- Fastify 어댑터 사용 시 `@Req()`, `@Res()` 타입은 Fastify의 `FastifyRequest`, `FastifyReply`가 됩니다.
- 권장: Nest의 추상화(`@Res()` 직접 사용 지양) 위에서 동작하도록 일반 컨트롤러 패턴 사용. 필요 시 `@Res({ passthrough: true })`로 헤더 설정 후 JSON 반환.

```ts
// src/example.controller.ts
import { Controller, Get, Res } from '@nestjs/common';
import { FastifyReply } from 'fastify';

@Controller('example')
export class ExampleController {
  @Get('hello')
  hello(@Res({ passthrough: true }) res: FastifyReply) {
    res.header('x-powered-by', 'fastify');
    return { ok: true };
  }
}
```

### 파일 업로드 (fastify-multipart)

```ts
// main.ts
import multipart from '@fastify/multipart';
// ...
await app.register(multipart, { limits: { fileSize: 10 * 1024 * 1024 } });
```

```ts
// controller 예시
import { Controller, Post, Req } from '@nestjs/common';
import { FastifyRequest } from 'fastify';

@Controller('upload')
export class UploadController {
  @Post()
  async upload(@Req() req: FastifyRequest) {
    const parts = req.parts();
    for await (const part of parts) {
      if (part.type === 'file') {
        // part.file: ReadableStream, part.filename, part.mimetype
      } else {
        // field 처리
      }
    }
    return { uploaded: true };
  }
}
```

### 정적 파일 제공 (fastify-static)

```ts
// main.ts
import fastifyStatic from '@fastify/static';
import { join } from 'path';
// ...
await app.register(fastifyStatic, {
  root: join(__dirname, '..', 'public'),
  prefix: '/public/',
});
```

### 쿠키/세션

```ts
// main.ts (이미 fastify-cookie 등록)
import session from '@fastify/session';
// ...
await app.register(session, {
  secret: process.env.SESSION_SECRET || 'dev-session',
  cookie: { secure: process.env.NODE_ENV === 'production', httpOnly: true },
});
```

### 웹소켓

- Fastify 자체 웹소켓 플러그인(`@fastify/websocket`)을 사용할 수도 있으나, Nest의 게이트웨이(`@nestjs/websockets`)와 `@nestjs/platform-socket.io` 혹은 `@nestjs/platform-ws`와 조합하여 사용하는 것이 일반적입니다.

```ts
// 예) Socket.IO 어댑터
import { IoAdapter } from '@nestjs/platform-socket.io';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter());
  app.useWebSocketAdapter(new IoAdapter(app));
  await app.listen(3000);
}
```

## Fastify와 Nest 파이프/밸리데이션

- Fastify는 AJV 스키마를 통한 검증을 지원하지만, Nest는 기본적으로 `class-validator` + `class-transformer` 파이프를 사용합니다.
- 두 접근을 혼용할 수 있으나, Nest 컨트롤러/DTO 중심의 개발에서는 Nest 파이프를 권장합니다.
- 고성능 스키마 검증이 필요하고 경로별로 Fastify 스키마를 활용하고자 할 때는, Fastify 라우트 레벨에서 스키마를 등록해야 합니다. Nest 표준 컨트롤러와 혼용하려면 커스텀 어댑터/미들웨어로 연결이 필요합니다(고급 패턴).

## 에러 처리와 로깅

- 로깅: `FastifyAdapter` 옵션 `logger: true` 시 pino 활성화. 구조적 로그로 운영 모니터링에 유리.
- 에러 처리: Nest의 `ExceptionFilter`와 함께 Fastify의 훅(`setErrorHandler`)을 병행 가능. 일반적으로 Nest 필터가 충분합니다.

```ts
// Fastify 에러 핸들러 (필요 시)
adapter.getInstance().setErrorHandler((error, req, reply) => {
  // 커스텀 포맷팅
  reply.status(500).send({ message: 'Internal Server Error' });
});
```

## 성능/운영 팁

- HTTP/2/TLS: Fastify 인스턴스 생성 시 `https`/`http2` 옵션으로 구성 가능
- 압축: `@fastify/compress` 전역 적용
- 헤더 보안: `@fastify/helmet`
- CORS: `@fastify/cors`로 상세 제어
- 프록시: `trustProxy: true` 설정 및 X-Forwarded-* 헤더 처리
- Keep-Alive/소켓 튜닝: 인프라/프록시 레벨과 함께 조정
- Graceful Shutdown: `app.enableShutdownHooks()`와 프로세스 시그널 핸들링

```ts
// main.ts
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter());
  app.enableShutdownHooks();

  process.on('SIGTERM', async () => {
    Logger.log('SIGTERM received, closing server...');
    await app.close();
    process.exit(0);
  });

  await app.listen(3000, '0.0.0.0');
}
```

## Express → Fastify 마이그레이션 체크리스트

- `@nestjs/platform-express` → `@nestjs/platform-fastify`
- `NestFactory.create(AppModule)` → `NestFactory.create<NestFastifyApplication>(AppModule, new FastifyAdapter())`
- 미들웨어/라이브러리 호환성 확인(예: multer → `@fastify/multipart`)
- `@Res()` 직접 제어 로직 최소화(플랫폼에 의존적이므로 Nest 추상화 우선)
- 정적 파일/쿠키/세션/웹소켓은 Fastify 플러그인으로 대체

## 샘플 AppModule

```ts
// src/app.module.ts
import { Module } from '@nestjs/common';
import { ExampleController } from './example.controller';

@Module({
  controllers: [ExampleController],
})
export class AppModule {}
```

## 결론

Fastify는 높은 성능과 일관된 스키마 기반 개발 경험을 제공하며, NestJS와의 결합을 통해 엔터프라이즈급 백엔드 애플리케이션을 효율적으로 구축할 수 있습니다. 초기 설정만 정리하면 Express 대비 적은 변경으로도 이점을 누릴 수 있으며, 운영 환경에서의 성능/관찰성/안정성 측면에서 유리합니다.
