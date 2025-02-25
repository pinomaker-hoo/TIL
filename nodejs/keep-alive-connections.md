# Keep Alive Connection

Keep-Alive Connection은 클라이언트와 서버 간의 연결을 유지하여 여러 요청을 하나의 TCP 연결에서 처리할 수 있도록 하는 기능이다. 기본적으로 HTTP/1.0에서는 요청이 끝날 때마다 TCP 연결이 닫히지만, HTTP/1.1부터는 기본적으로 Keep-Alive가 활성화되어 여러 요청을 같은 연결에서 처리할 수 있다.

장점

- 성능 향상 : 새 연결을 설정하는 오버헤드(TCP 핸드셰이크 감소) 감소
- 지연 시간 단축 : 연결 설정 시간을 줄여 응답 속도 향상
- 리소스 절약 : 서버와 클라이언트의 네트워크 리소스 절약

headersTimeout은 keepAliveTimeout보다 살짝 길게 설정해야하며, Node의 경우 별도 설정이 없을 경우 5S로 잡혀있다.

## NodeJS Sample Code

```javascript
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import * as http from "http";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Express의 기본 HTTP 서버 가져오기
  const server = http.createServer(app.getHttpAdapter().getInstance());

  // Keep-Alive 설정 (ms 단위)
  server.keepAliveTimeout = 60000; // 60초 동안 연결 유지
  server.headersTimeout = 65000; // 65초 후에 연결 강제 종료

  server.listen(3000, () => {
    console.log("NestJS Express server running on port 3000");
  });
}
bootstrap();
```

## NestJS Sample Code

```javascript
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";
import * as express from "express";
import * as http from "http";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const server = http.createServer(app.getHttpAdapter().getInstance());

  server.keepAliveTimeout = 5000; // Keep-Alive 유지 시간 설정

  server.listen(3000, () => {
    console.log("NestJS server running on port 3000");
  });
}
bootstrap();
```
