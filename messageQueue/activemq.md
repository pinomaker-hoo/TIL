# ActiveMQ

## 개요

Apache ActiveMQ는 Apache Software Foundation에서 개발한 오픈소스 메세지 브로커다. JMS(Java Message Service) 스펙을 완전히 구현하며, 엔터프라이즈 환경에서 오랜 기간 사용되어 온 안정적인 메세징 솔루션이다.

현재 두 가지 버전이 존재한다.
- **ActiveMQ Classic**: 기존 버전으로, 풍부한 기능과 다양한 프로토콜을 지원한다.
- **ActiveMQ Artemis**: 차세대 버전으로, 고성능 비차단(Non-Blocking) 아키텍처를 기반으로 설계되었다. 신규 프로젝트에서는 Artemis를 권장한다.

## 핵심 개념

### Queue (Point-to-Point)

하나의 메세지를 하나의 Consumer만 소비하는 패턴이다. 여러 Consumer가 연결되어 있으면 라운드 로빈 방식으로 분배된다.

### Topic (Publish/Subscribe)

하나의 메세지를 모든 Subscriber에게 전달하는 패턴이다. Publisher가 메세지를 발행하면 구독 중인 모든 Subscriber가 수신한다.

### Durable Subscriber

Topic의 Subscriber가 연결이 끊겨도 메세지를 보존하여, 재연결 시 놓친 메세지를 받을 수 있는 기능이다.

### Message Acknowledgement

Consumer가 메세지를 정상적으로 처리했음을 Broker에 알리는 메커니즘이다.

- **AUTO_ACKNOWLEDGE**: 메세지 수신 시 자동 ACK
- **CLIENT_ACKNOWLEDGE**: 클라이언트가 명시적으로 ACK
- **SESSION_TRANSACTED**: 트랜잭션 커밋 시 ACK

### Message Persistence

메세지를 디스크에 저장하여 Broker 재시작 후에도 메세지를 보존한다. KahaDB(기본), JDBC, LevelDB 등의 저장소를 사용할 수 있다.

## 지원 프로토콜

ActiveMQ의 강점 중 하나는 다양한 프로토콜을 동시에 지원한다는 점이다.

| 프로토콜 | 설명 | 포트 |
|----------|------|------|
| OpenWire | Java 클라이언트 기본 프로토콜 | 61616 |
| AMQP | 표준 메세징 프로토콜 | 5672 |
| STOMP | 텍스트 기반 간단한 프로토콜 | 61613 |
| MQTT | IoT/경량 디바이스용 프로토콜 | 1883 |
| WebSocket | 웹 브라우저 통신 | 61614 |

## ActiveMQ vs RabbitMQ 비교

| 항목 | ActiveMQ | RabbitMQ |
|------|----------|----------|
| 표준 | JMS 완전 구현 | AMQP 구현 |
| 언어 | Java | Erlang |
| 프로토콜 | OpenWire/AMQP/STOMP/MQTT | AMQP (+ STOMP/MQTT 플러그인) |
| 라우팅 | 기본적 (Composite Destination) | Exchange 기반 다양한 라우팅 |
| 성능 | 중간 | 높음 (큐가 비어있을 때 매우 빠름) |
| 적합한 케이스 | Java/JMS 엔터프라이즈 환경 | 다양한 언어, 복잡한 라우팅 |

## Docker로 실행

```bash
# ActiveMQ Classic
docker run -p 61616:61616 -p 8161:8161 apache/activemq-classic:latest

# ActiveMQ Artemis
docker run -p 61616:61616 -p 8161:8161 apache/activemq-artemis:latest
```

- 61616: 메세지 브로커 포트
- 8161: 웹 관리 콘솔 (기본 계정: admin/admin)

## Node.js에서 ActiveMQ 사용 (STOMP)

### 설치

```bash
npm install stompit
```

### Producer

```ts
import stompit from 'stompit';

const connectOptions = {
  host: 'localhost',
  port: 61613,
  connectHeaders: {
    host: '/',
    login: 'admin',
    passcode: 'admin',
  },
};

stompit.connect(connectOptions, (error, client) => {
  if (error) {
    console.error('Connection error:', error);
    return;
  }

  const frame = client.send({
    destination: '/queue/orders',
    'content-type': 'application/json',
  });

  frame.write(JSON.stringify({ orderId: 1, product: 'Laptop' }));
  frame.end();

  client.disconnect();
});
```

### Consumer

```ts
stompit.connect(connectOptions, (error, client) => {
  if (error) {
    console.error('Connection error:', error);
    return;
  }

  const subscribeHeaders = {
    destination: '/queue/orders',
    ack: 'client-individual',
  };

  client.subscribe(subscribeHeaders, (error, message) => {
    if (error) {
      console.error('Subscribe error:', error);
      return;
    }

    message.readString('utf-8', (error, body) => {
      if (error) {
        console.error('Read error:', error);
        return;
      }
      console.log('Received:', JSON.parse(body!));
      client.ack(message);
    });
  });
});
```

## 주요 기능

### Virtual Destinations

Topic과 Queue를 결합하여 Topic으로 발행된 메세지를 Queue로 라우팅할 수 있다.

```
# Topic에 발행하면 연결된 Queue로 자동 라우팅
VirtualTopic.Orders → Consumer.A.VirtualTopic.Orders
                    → Consumer.B.VirtualTopic.Orders
```

### Message Groups

같은 그룹 키를 가진 메세지를 동일 Consumer에게 라우팅하여 순서를 보장한다.

### Scheduled Messages

메세지에 지연 시간을 설정하여 예약 전달이 가능하다.

### Broker Network

여러 Broker를 네트워크로 연결하여 분산 환경을 구성할 수 있다.

## 운영 시 고려사항

- **저장소 선택**: 프로덕션에서는 KahaDB(기본) 또는 JDBC 기반 저장소를 사용하고 정기적으로 백업한다.
- **메모리 관리**: `systemUsage` 설정으로 메모리/디스크 사용량 한도를 설정한다.
- **모니터링**: 웹 콘솔(8161), JMX, Hawtio 등을 통해 큐 깊이, Consumer 상태를 모니터링한다.
- **보안**: 인증(JAAS), 권한 관리, TLS를 적용한다.
- **버전 선택**: 신규 프로젝트에서는 성능이 개선된 ActiveMQ Artemis를 권장한다.
- **Dead Letter Queue**: 처리 실패 메세지는 자동으로 `ActiveMQ.DLQ`에 이동되며, 이를 모니터링해야 한다.
