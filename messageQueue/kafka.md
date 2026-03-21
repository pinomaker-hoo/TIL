# Apache Kafka

## 개요

Apache Kafka는 LinkedIn에서 개발하고 Apache Software Foundation에 기부된 오픈소스 분산 이벤트 스트리밍 플랫폼이다. 대용량 실시간 데이터 파이프라인과 스트리밍 애플리케이션을 구축하는 데 사용되며, 높은 처리량(Throughput), 내구성(Durability), 확장성(Scalability)을 제공한다.

기존의 메세지 큐(RabbitMQ, ActiveMQ 등)와 달리 메세지를 디스크에 영구 저장하고, Consumer가 메세지를 소비해도 삭제하지 않는 로그(Log) 기반 아키텍처를 채택하고 있다.

## 핵심 개념

### Broker

Kafka 클러스터를 구성하는 개별 서버를 Broker라고 한다. 각 Broker는 고유한 ID를 가지며, Topic의 Partition 데이터를 저장하고 관리한다. 여러 Broker가 모여 하나의 Kafka 클러스터를 구성하게 된다.

### Topic

메세지를 분류하는 논리적 채널이다. Producer는 특정 Topic에 메세지를 발행하고, Consumer는 특정 Topic을 구독하여 메세지를 소비한다. RDB의 테이블과 유사한 개념이다.

### Partition

Topic은 하나 이상의 Partition으로 나뉘며, 각 Partition은 순서가 보장되는 불변의 메세지 시퀀스(Log)다. Partition을 여러 개 두면 병렬 처리가 가능해져 처리량을 높일 수 있다.

- 각 Partition 내부에서는 메세지 순서가 보장된다.
- 서로 다른 Partition 간에는 순서가 보장되지 않는다.
- Partition 수는 늘릴 수 있지만 줄일 수는 없다.

### Offset

Partition 내에서 각 메세지에 부여되는 고유한 순차 번호(ID)다. Consumer는 자신이 어디까지 읽었는지를 Offset으로 관리하며, 이를 통해 재처리나 특정 시점부터의 재소비가 가능하다.

### Producer

메세지를 생성하고 특정 Topic에 발행하는 주체다. Producer는 메세지를 보낼 때 Key를 지정할 수 있으며, 같은 Key를 가진 메세지는 같은 Partition에 할당되어 순서가 보장된다.

### Consumer

Topic을 구독하고 메세지를 소비하는 주체다. Consumer는 Pull 방식으로 Broker로부터 메세지를 가져온다.

### Consumer Group

여러 Consumer를 하나의 그룹으로 묶어 Topic의 Partition을 분산 처리하는 단위다. 하나의 Partition은 Consumer Group 내에서 하나의 Consumer만 할당받을 수 있다. 이를 통해 수평적 확장이 가능하다.

```
Topic (3 Partitions)
├── Partition 0 → Consumer A (Group 1)
├── Partition 1 → Consumer B (Group 1)
└── Partition 2 → Consumer C (Group 1)
```

Consumer Group 내 Consumer 수가 Partition 수보다 많으면 유휴(Idle) Consumer가 발생한다.

### Replication

각 Partition은 여러 Broker에 복제(Replica)될 수 있다. Replication Factor를 설정하여 장애 시에도 데이터 손실을 방지한다.

- Leader Replica: 읽기/쓰기를 담당하는 메인 복제본
- Follower Replica: Leader를 복제하며 Leader 장애 시 승격

### Zookeeper / KRaft

- Zookeeper: Kafka 2.x까지 클러스터 메타데이터 관리, Broker 탐지, Leader 선출 등을 담당했다.
- KRaft(Kafka Raft): Kafka 3.x부터 도입된 자체 메타데이터 관리 모드로, Zookeeper 의존성을 제거한다. Kafka 3.5+에서 Production Ready로 선언되었다.

## Kafka vs RabbitMQ 비교

| 항목 | Kafka | RabbitMQ |
|------|-------|----------|
| 아키텍처 | 분산 로그 기반 | AMQP 기반 메세지 브로커 |
| 메세지 보존 | 소비 후에도 보존 (보존 기간 설정) | 소비 후 삭제 (ACK 기반) |
| 처리량 | 초당 수백만 건 | 초당 수만~수십만 건 |
| 순서 보장 | Partition 단위 보장 | 단일 Consumer 시 보장 |
| 소비 방식 | Pull 방식 | Push 방식 |
| 재처리 | Offset 기반 재소비 가능 | 기본적으로 불가 |
| 적합한 케이스 | 대용량 스트리밍, 로그 수집, 이벤트 소싱 | 작업 큐, 라우팅이 복잡한 메세징 |

## Kafka 주요 특징

- **높은 처리량**: 배치 처리, Zero-Copy, 순차 디스크 I/O를 통해 높은 성능을 제공한다.
- **내구성**: 디스크 기반 저장 + 복제를 통해 데이터 유실을 방지한다.
- **확장성**: Broker와 Partition 추가만으로 수평 확장이 가능하다.
- **메세지 재처리**: Offset을 조정하여 과거 메세지를 다시 소비할 수 있다.
- **Exactly Once Semantics**: 트랜잭션과 멱등성 Producer를 통해 정확히 한 번 처리를 지원한다.

## Producer 설정 주요 옵션

- `acks`: 메세지 전송 확인 수준
  - `0`: 확인 없이 전송 (가장 빠름, 유실 가능)
  - `1`: Leader만 확인 (기본값)
  - `all(-1)`: 모든 Replica 확인 (가장 안전)
- `retries`: 전송 실패 시 재시도 횟수
- `batch.size`: 배치 크기 (바이트)
- `linger.ms`: 배치 전송 대기 시간 (ms)
- `compression.type`: 압축 방식 (`none`, `gzip`, `snappy`, `lz4`, `zstd`)

## Consumer 설정 주요 옵션

- `group.id`: Consumer Group 식별자
- `auto.offset.reset`: 초기 Offset이 없을 때 동작 (`earliest`, `latest`)
- `enable.auto.commit`: 자동 Offset 커밋 여부
- `max.poll.records`: 한 번의 poll()에서 가져올 최대 레코드 수
- `session.timeout.ms`: Consumer 세션 타임아웃

## Topic 설정 주요 옵션

- `retention.ms`: 메세지 보존 기간 (기본 7일)
- `retention.bytes`: Partition당 최대 보존 크기
- `cleanup.policy`: `delete`(기간/용량 초과 시 삭제) 또는 `compact`(Key 기준 최신 값만 유지)
- `min.insync.replicas`: `acks=all` 시 최소 동기화 Replica 수

## 사용 사례

- **실시간 로그 수집/분석**: 서버 로그, 애플리케이션 이벤트를 중앙 집중 수집
- **이벤트 소싱(Event Sourcing)**: 상태 변경을 이벤트 로그로 저장
- **CDC(Change Data Capture)**: 데이터베이스 변경 사항을 실시간으로 스트리밍
- **마이크로서비스 간 비동기 통신**: 서비스 간 느슨한 결합을 위한 이벤트 기반 아키텍처
- **실시간 데이터 파이프라인**: ETL 대체, 실시간 데이터 동기화

## Docker Compose 예시 (KRaft 모드)

```yaml
version: '3.8'
services:
  kafka:
    image: confluentinc/cp-kafka:7.5.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      CLUSTER_ID: 'MkU3OEVBNTcwNTJENDM2Qk'
```

## Node.js에서 Kafka 사용 (KafkaJS)

### 설치

```bash
npm install kafkajs
```

### Producer 예시

```ts
import { Kafka } from 'kafkajs';

const kafka = new Kafka({
  clientId: 'my-app',
  brokers: ['localhost:9092'],
});

const producer = kafka.producer();

async function sendMessage() {
  await producer.connect();
  await producer.send({
    topic: 'user-events',
    messages: [
      { key: 'user-1', value: JSON.stringify({ action: 'login', timestamp: Date.now() }) },
    ],
  });
  await producer.disconnect();
}
```

### Consumer 예시

```ts
const consumer = kafka.consumer({ groupId: 'event-processor' });

async function consumeMessages() {
  await consumer.connect();
  await consumer.subscribe({ topic: 'user-events', fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      console.log({
        topic,
        partition,
        offset: message.offset,
        key: message.key?.toString(),
        value: message.value?.toString(),
      });
    },
  });
}
```

## 운영 시 고려사항

- **Partition 수 결정**: Consumer 수와 처리량을 고려하여 적절히 설정한다. 너무 많으면 리소스 낭비, 너무 적으면 병렬 처리 제한.
- **Replication Factor**: 프로덕션에서는 최소 3으로 설정을 권장한다.
- **모니터링**: Consumer Lag(처리 지연)을 핵심 지표로 모니터링한다.
- **디스크 관리**: 로그 보존 정책을 적절히 설정하여 디스크 사용량을 관리한다.
- **보안**: SASL/SSL 인증, ACL 기반 접근 제어를 적용한다.
