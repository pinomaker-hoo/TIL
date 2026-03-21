# NATS

## 개요

NATS는 CNCF(Cloud Native Computing Foundation) 졸업 프로젝트로, 경량 고성능 메세징 시스템이다. 클라우드 네이티브 환경과 마이크로서비스 아키텍처에 최적화되어 있으며, 단순한 텍스트 기반 프로토콜을 사용하여 매우 빠른 속도를 제공한다.

Go로 작성되어 단일 바이너리로 배포되며, 설정이 거의 없이도 바로 사용할 수 있다.

## 핵심 개념

### Subject

메세지를 분류하는 주소(Address)다. 계층적 네이밍을 지원하며 `.`으로 구분한다.

```
orders.created
orders.us.created
notifications.email.send
```

### Publish/Subscribe

기본 메세징 패턴으로, Publisher가 Subject에 메세지를 발행하면 해당 Subject를 구독 중인 모든 Subscriber가 메세지를 수신한다.

### Request/Reply

동기적 요청-응답 패턴을 지원한다. 요청자가 메세지를 보내면 응답자가 처리 후 결과를 반환한다. 내부적으로 임시 Subject를 사용한다.

### Queue Group

같은 Queue Group에 속한 Subscriber 중 하나만 메세지를 수신하는 로드밸런싱 패턴이다. Consumer Group과 유사한 개념이다.

### Wildcard

Subject 매칭에 와일드카드를 사용할 수 있다.
- `*`: 단일 토큰 매칭 (`orders.*.created`)
- `>`: 나머지 전체 매칭 (`orders.>`)

## NATS Core vs JetStream

### NATS Core

- At-Most-Once 전달 (메세지 유실 가능)
- 메세지 영속화 없음 (Fire-and-Forget)
- 매우 빠른 속도
- 실시간 통신에 적합

### JetStream

NATS 2.2+에서 도입된 영속화 레이어다.

- At-Least-Once / Exactly-Once 전달 보장
- 메세지를 Stream에 디스크/메모리로 영속화
- Consumer 기반 메세지 소비 (ACK/NACK 지원)
- 메세지 재처리, 보존 정책, Key-Value Store 기능
- Kafka와 유사한 기능을 경량으로 제공

| 항목 | NATS Core | JetStream |
|------|-----------|-----------|
| 전달 보장 | At-Most-Once | At-Least-Once / Exactly-Once |
| 영속화 | 없음 | 디스크/메모리 |
| 속도 | 매우 빠름 | 빠름 |
| 적합한 케이스 | 실시간 시그널링 | 이벤트 소싱, 작업 큐 |

## NATS vs Kafka 비교

| 항목 | NATS | Kafka |
|------|------|-------|
| 설계 목적 | 경량 메세징 | 대용량 이벤트 스트리밍 |
| 설치/운영 | 단일 바이너리, 매우 간단 | 클러스터 운영 복잡 |
| 프로토콜 | 텍스트 기반 (간단) | 바이너리 (복잡) |
| 지연시간(Latency) | 매우 낮음 (마이크로초) | 낮음 (밀리초) |
| 영속화 | JetStream으로 선택적 | 기본 디스크 영속화 |
| 클라이언트 지원 | 40+ 언어 | 다수 언어 |
| 적합한 케이스 | 마이크로서비스, IoT | 대용량 로그, 이벤트 소싱 |

## Docker로 실행

```bash
# NATS Core
docker run -p 4222:4222 -p 8222:8222 nats:latest

# JetStream 활성화
docker run -p 4222:4222 -p 8222:8222 nats:latest -js
```

- 4222: 클라이언트 연결 포트
- 8222: HTTP 모니터링 포트

## Node.js에서 NATS 사용

### 설치

```bash
npm install nats
```

### Pub/Sub 예시

```ts
import { connect, StringCodec } from 'nats';

const nc = await connect({ servers: 'localhost:4222' });
const sc = StringCodec();

// Subscriber
const sub = nc.subscribe('orders.created');
(async () => {
  for await (const msg of sub) {
    console.log('Received:', sc.decode(msg.data));
  }
})();

// Publisher
nc.publish('orders.created', sc.encode(JSON.stringify({ orderId: 1 })));
```

### Request/Reply 예시

```ts
// Responder
const sub = nc.subscribe('api.users.get');
(async () => {
  for await (const msg of sub) {
    const request = JSON.parse(sc.decode(msg.data));
    msg.respond(sc.encode(JSON.stringify({ id: request.id, name: 'John' })));
  }
})();

// Requester
const response = await nc.request('api.users.get', sc.encode(JSON.stringify({ id: 1 })), {
  timeout: 5000,
});
console.log('Response:', sc.decode(response.data));
```

### Queue Group 예시

```ts
// 같은 Queue Group의 여러 Consumer 중 하나만 메세지를 수신
const sub = nc.subscribe('tasks.process', { queue: 'worker-group' });
(async () => {
  for await (const msg of sub) {
    console.log('Worker processing:', sc.decode(msg.data));
  }
})();
```

### JetStream 예시

```ts
import { connect, StringCodec, AckPolicy } from 'nats';

const nc = await connect({ servers: 'localhost:4222' });
const js = nc.jetstream();
const jsm = await nc.jetstreamManager();
const sc = StringCodec();

// Stream 생성
await jsm.streams.add({
  name: 'ORDERS',
  subjects: ['orders.>'],
});

// 메세지 발행
await js.publish('orders.created', sc.encode(JSON.stringify({ orderId: 1 })));

// Consumer로 소비
const consumer = await js.consumers.get('ORDERS', 'order-processor');
const messages = await consumer.consume();

for await (const msg of messages) {
  console.log('Processing:', sc.decode(msg.data));
  msg.ack();
}
```

## NestJS에서 NATS 사용

NestJS는 `@nestjs/microservices`를 통해 NATS를 기본 지원한다.

```ts
// main.ts
import { NestFactory } from '@nestjs/core';
import { MicroserviceOptions, Transport } from '@nestjs/microservices';

const app = await NestFactory.createMicroservice<MicroserviceOptions>(AppModule, {
  transport: Transport.NATS,
  options: {
    servers: ['nats://localhost:4222'],
  },
});
await app.listen();
```

```ts
// Controller
import { Controller } from '@nestjs/common';
import { MessagePattern, EventPattern } from '@nestjs/microservices';

@Controller()
export class OrdersController {
  @MessagePattern('orders.get')
  getOrder(data: { id: number }) {
    return { id: data.id, status: 'completed' };
  }

  @EventPattern('orders.created')
  handleOrderCreated(data: { orderId: number }) {
    console.log('Order created:', data.orderId);
  }
}
```

## 운영 시 고려사항

- **클러스터링**: 프로덕션에서는 최소 3개 노드로 클러스터를 구성하여 고가용성을 확보한다.
- **JetStream 활용**: 메세지 유실이 허용되지 않는 경우 반드시 JetStream을 사용한다.
- **모니터링**: 8222 포트의 HTTP 모니터링 엔드포인트를 활용한다.
- **메세지 크기**: 기본 최대 메세지 크기는 1MB이며, 큰 데이터는 Object Store를 활용한다.
- **보안**: TLS, 토큰/NKey/JWT 기반 인증을 적용한다.
