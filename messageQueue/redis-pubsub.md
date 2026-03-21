# Redis Pub/Sub

## 개요

Redis Pub/Sub은 Redis에 내장된 경량 발행/구독(Publish/Subscribe) 메세징 시스템이다. 별도의 메세지 브로커 없이 Redis만으로 간단한 실시간 메세징을 구현할 수 있다.

메세지를 영속화하지 않으며, 구독자가 연결되어 있지 않으면 메세지가 유실되는 Fire-and-Forget 방식이다.

## 핵심 개념

### Channel

메세지를 분류하는 채널(주소)이다. Publisher가 특정 Channel에 메세지를 발행하면, 해당 Channel을 구독 중인 모든 Subscriber가 메세지를 수신한다.

### Publisher

`PUBLISH` 명령어로 특정 Channel에 메세지를 발행하는 주체다.

### Subscriber

`SUBSCRIBE` 명령어로 특정 Channel을 구독하는 주체다. 구독 상태에서는 다른 Redis 명령어를 실행할 수 없다 (전용 연결 필요).

### Pattern Subscribe

`PSUBSCRIBE` 명령어로 패턴 기반 구독이 가능하다.

```
PSUBSCRIBE orders.*       # orders.created, orders.updated 등 매칭
PSUBSCRIBE notifications.# # notifications. 으로 시작하는 모든 채널
```

## Redis Pub/Sub의 특징

- **메세지 미보존**: 메세지를 저장하지 않으며, 발행 시점에 구독자가 없으면 메세지가 유실된다.
- **At-Most-Once 전달**: 최대 1회 전달만 보장하며, 재시도/ACK 메커니즘이 없다.
- **전용 연결 필요**: Subscriber는 구독 모드에서 다른 명령을 실행할 수 없어 별도의 Redis 연결이 필요하다.
- **매우 빠름**: 별도의 영속화 오버헤드가 없어 매우 낮은 지연시간을 제공한다.
- **브로드캐스트**: 모든 구독자에게 메세지를 전달한다 (로드밸런싱 미지원).

## Redis Pub/Sub vs Redis Streams

| 항목 | Redis Pub/Sub | Redis Streams |
|------|---------------|---------------|
| 메세지 보존 | 보존 안 함 | 영속화 (보존 기간 설정 가능) |
| 전달 보장 | At-Most-Once | At-Least-Once |
| Consumer Group | 미지원 | 지원 (로드밸런싱 가능) |
| ACK | 미지원 | 지원 |
| 재처리 | 불가 | 가능 |
| 적합한 케이스 | 실시간 알림, 캐시 무효화 | 이벤트 로그, 작업 큐 |

메세지 유실이 허용되지 않는 경우 Redis Streams를 사용하는 것을 권장한다.

## Redis CLI 예시

```bash
# Terminal 1 - Subscriber
redis-cli SUBSCRIBE chat:room1

# Terminal 2 - Publisher
redis-cli PUBLISH chat:room1 "Hello, World!"

# Pattern Subscribe
redis-cli PSUBSCRIBE "chat:*"
```

## Node.js에서 Redis Pub/Sub 사용

### 설치

```bash
npm install ioredis
```

### Publisher

```ts
import Redis from 'ioredis';

const publisher = new Redis({ host: '127.0.0.1', port: 6379 });

await publisher.publish('notifications', JSON.stringify({
  type: 'order_created',
  orderId: 123,
  timestamp: Date.now(),
}));
```

### Subscriber

```ts
import Redis from 'ioredis';

// 구독 전용 연결 (다른 명령어 사용 불가)
const subscriber = new Redis({ host: '127.0.0.1', port: 6379 });

subscriber.subscribe('notifications', (err, count) => {
  console.log(`Subscribed to ${count} channels`);
});

subscriber.on('message', (channel, message) => {
  const data = JSON.parse(message);
  console.log(`[${channel}] Received:`, data);
});

// 패턴 구독
subscriber.psubscribe('orders.*');
subscriber.on('pmessage', (pattern, channel, message) => {
  console.log(`[${pattern}] ${channel}:`, message);
});
```

## 적합한 사용 사례

- **실시간 알림**: 채팅 메세지, 실시간 알림 전달
- **캐시 무효화(Cache Invalidation)**: 데이터 변경 시 여러 서버의 로컬 캐시를 동시에 무효화
- **실시간 대시보드**: 메트릭, 상태 업데이트를 실시간으로 전달
- **WebSocket 브로드캐스트**: 다중 서버 환경에서 WebSocket 메세지를 동기화
- **설정 변경 전파**: 설정이 변경되었을 때 모든 인스턴스에 알림

## 부적합한 사용 사례

- 메세지 유실이 허용되지 않는 작업 큐 → BullMQ, Kafka 사용
- 대용량 이벤트 스트리밍 → Kafka, NATS JetStream 사용
- 메세지 재처리가 필요한 경우 → Redis Streams, Kafka 사용
- 복잡한 라우팅이 필요한 경우 → RabbitMQ 사용

## 운영 시 고려사항

- **전용 연결**: Subscriber용 Redis 연결을 별도로 생성해야 한다.
- **메세지 유실 감수**: 네트워크 장애나 구독자 부재 시 메세지가 유실될 수 있다.
- **대규모 브로드캐스트 주의**: 다수의 Subscriber에게 대량의 메세지를 전달하면 Redis 부하가 증가한다.
- **클러스터 모드**: Redis Cluster에서는 Pub/Sub이 모든 노드에 메세지를 전파하므로 주의가 필요하다.
- **대안 검토**: 신뢰성이 필요하면 Redis Streams, 더 복잡한 요구사항이 있으면 전용 메세지 브로커를 고려한다.
