# Message Queue

## 개요

메세지 큐(Message Queue)에 대해 학습합니다. 메세지 큐는 분산 시스템에서 서비스 간 비동기 통신을 위해 사용되는 미들웨어로, Producer가 메세지를 큐에 발행하고 Consumer가 이를 소비하는 구조다.

## 목차

### 메세지 브로커 / 이벤트 스트리밍

- [Apache Kafka](./kafka.md) - 분산 이벤트 스트리밍 플랫폼, 대용량 실시간 데이터 파이프라인
- [RabbitMQ](./rabbitmq.md) - AMQP 기반 오픈소스 메세지 브로커, 다양한 Exchange 라우팅
- [Amazon SQS](./amazon-sqs.md) - AWS 완전관리형 메세지 큐 서비스
- [Amazon Kinesis](./kinesis.md) - AWS 완전관리형 실시간 데이터 스트리밍 서비스
- [NATS](./nats.md) - 경량 고성능 메세징 시스템, 클라우드 네이티브
- [ActiveMQ](./activemq.md) - JMS 기반 오픈소스 메세지 브로커

### 작업 큐 (Task Queue)

- [BullMQ](./bullmq.md) - Redis 기반 Node.js 고성능 작업 큐

### Pub/Sub

- [Redis Pub/Sub](./redis-pubsub.md) - Redis 기반 경량 Pub/Sub 메세징

## 메세지 큐 선택 가이드

| 기준 | Kafka | RabbitMQ | Amazon SQS | Kinesis | BullMQ | NATS | ActiveMQ |
|------|-------|----------|------------|---------|--------|------|----------|
| 처리량 | 매우 높음 | 중간 | 높음 | 매우 높음 | 중간 | 매우 높음 | 중간 |
| 메세지 보존 | 디스크 영구 보존 | 소비 후 삭제 | 최대 14일 | 최대 365일 | Redis 의존 | 기본 미보존 | 소비 후 삭제 |
| 순서 보장 | Partition 단위 | 단일 Consumer | FIFO 큐 지원 | Shard 단위 | 큐 단위 | Stream 지원 | 큐 단위 |
| 프로토콜 | 자체 프로토콜 | AMQP | HTTP/SQS API | HTTP/SDK | Redis | 자체/MQTT/WS | JMS/AMQP/STOMP |
| 인프라 | 자체 클러스터 | 자체 서버 | AWS 관리형 | AWS 관리형 | Redis만 필요 | 자체 서버 | 자체 서버 |
| 적합한 케이스 | 이벤트 스트리밍 | 복잡한 라우팅 | 서버리스/AWS | 실시간 스트리밍/AWS | Node.js 작업 큐 | 마이크로서비스 | Java/엔터프라이즈 |
