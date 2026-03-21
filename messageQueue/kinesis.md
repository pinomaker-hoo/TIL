# Amazon Kinesis

## 개요

Amazon Kinesis는 AWS에서 제공하는 완전관리형 실시간 데이터 스트리밍 서비스다. 대용량의 스트리밍 데이터를 실시간으로 수집, 처리, 분석할 수 있으며, 초당 수십만~수백만 건의 레코드를 처리할 수 있다.

Kafka와 유사한 역할을 하지만 AWS 관리형으로 인프라 운영 부담 없이 사용할 수 있다.

## Kinesis 서비스 종류

### Kinesis Data Streams (KDS)

실시간 데이터 스트리밍의 핵심 서비스다. Producer가 레코드를 Stream에 넣으면 Consumer가 이를 실시간으로 소비한다. 본 문서에서 주로 다루는 서비스다.

### Kinesis Data Firehose

스트리밍 데이터를 S3, Redshift, OpenSearch, Splunk 등 대상(Destination)으로 자동 전달하는 서비스다. 별도의 Consumer 코드 없이 데이터를 적재할 수 있다.

### Kinesis Data Analytics

SQL이나 Apache Flink를 사용하여 스트리밍 데이터를 실시간으로 분석하는 서비스다.

### Kinesis Video Streams

비디오 스트림을 수집, 저장, 처리하는 서비스다.

## 핵심 개념 (Data Streams)

### Stream

데이터를 저장하는 논리적 단위다. 하나 이상의 Shard로 구성된다.

### Shard

Stream의 처리 단위이자 용량 단위다. 각 Shard는 고정된 처리량을 가진다.

- 쓰기: 초당 1,000 레코드 또는 1MB
- 읽기: 초당 2MB (공유) 또는 Shard당 Consumer별 2MB (Enhanced Fan-Out)

Shard 수를 늘리면 처리량이 선형적으로 증가한다.

### Record

Stream에 저장되는 데이터 단위다. 구성 요소:
- **Partition Key**: 레코드가 어떤 Shard에 할당될지 결정하는 키
- **Sequence Number**: Shard 내에서 레코드에 부여되는 고유 순서 번호
- **Data Blob**: 실제 데이터 (최대 1MB)

### Partition Key

Partition Key를 해싱하여 레코드가 할당될 Shard를 결정한다. 같은 Partition Key를 가진 레코드는 같은 Shard에 저장되어 순서가 보장된다. Kafka의 메세지 Key와 동일한 역할이다.

### Retention Period

레코드 보존 기간이다. 기본 24시간이며 최대 365일까지 설정할 수 있다.

### Consumer 유형

**Shared (Classic) Fan-Out**
- 같은 Shard의 읽기 처리량(2MB/s)을 모든 Consumer가 공유한다.
- `GetRecords` API를 사용하며 Pull 방식이다.
- 비용이 저렴하지만 Consumer 수가 많으면 처리량이 분산된다.

**Enhanced Fan-Out**
- Consumer별로 Shard당 2MB/s의 전용 처리량을 제공한다.
- `SubscribeToShard` API를 사용하며 Push 방식이다.
- 비용이 더 높지만 다수의 Consumer가 독립적으로 높은 처리량을 확보할 수 있다.

## Kinesis vs Kafka 비교

| 항목 | Kinesis Data Streams | Apache Kafka |
|------|---------------------|--------------|
| 운영 | AWS 완전관리형 | 자체 클러스터 운영 필요 |
| 용량 단위 | Shard (고정 처리량) | Partition (유연) |
| 쓰기 처리량 | Shard당 1MB/s | Partition당 제한 없음 (디스크 의존) |
| 보존 기간 | 최대 365일 | 무제한 (설정 기반) |
| 순서 보장 | Shard 단위 | Partition 단위 |
| 소비 방식 | Pull + Enhanced Fan-Out(Push) | Pull |
| 확장 | Shard 분할/병합 | Partition 추가 |
| 비용 | Shard 시간 + 데이터량 과금 | 인프라 비용 |
| 생태계 | AWS 서비스 연동 (Lambda, Firehose) | Kafka Connect, Streams, ksqlDB |
| 적합한 케이스 | AWS 중심 아키텍처, 서버리스 | 대용량, 멀티클라우드, 온프레미스 |

## Kinesis vs SQS 비교

| 항목 | Kinesis Data Streams | Amazon SQS |
|------|---------------------|------------|
| 패턴 | 스트리밍 (다수 Consumer) | 작업 큐 (단일 Consumer) |
| 순서 | Shard 단위 보장 | FIFO 큐에서만 보장 |
| 보존 | 최대 365일 | 최대 14일 |
| 다중 Consumer | 지원 (Fan-Out) | 미지원 (1 메세지 = 1 Consumer) |
| 재처리 | Shard Iterator로 가능 | 불가 |
| 처리량 | Shard 기반 프로비저닝 | 자동 확장 |
| 적합한 케이스 | 로그 수집, 실시간 분석 | 비동기 작업 큐, 디커플링 |

## 주요 특징

- **실시간 처리**: 데이터 수집 후 밀리초 이내에 소비 가능
- **순서 보장**: Shard 내에서 엄격한 순서 보장
- **내구성**: 3개 AZ에 동기 복제하여 데이터 유실 방지
- **확장성**: Shard 분할/병합으로 처리량을 동적으로 조정 (On-Demand 모드도 지원)
- **AWS 연동**: Lambda, Firehose, Analytics, S3 등과 네이티브 연동

## 용량 모드

### Provisioned Mode
- Shard 수를 직접 지정하여 처리량을 프로비저닝한다.
- 예측 가능한 트래픽에 적합하며, Shard 시간 단위로 과금된다.

### On-Demand Mode
- 트래픽에 따라 자동으로 Shard가 확장/축소된다.
- 예측 불가능한 트래픽에 적합하며, 데이터량 단위로 과금된다.

## AWS SDK (Node.js) 사용 예시

### 설치

```bash
npm install @aws-sdk/client-kinesis
```

### Producer

```ts
import { KinesisClient, PutRecordCommand } from '@aws-sdk/client-kinesis';

const client = new KinesisClient({ region: 'ap-northeast-2' });

async function putRecord() {
  const command = new PutRecordCommand({
    StreamName: 'my-stream',
    PartitionKey: 'user-123',
    Data: Buffer.from(JSON.stringify({
      eventType: 'page_view',
      userId: 123,
      timestamp: Date.now(),
    })),
  });

  const response = await client.send(command);
  console.log('SequenceNumber:', response.SequenceNumber);
  console.log('ShardId:', response.ShardId);
}
```

### 배치 Producer

```ts
import { PutRecordsCommand } from '@aws-sdk/client-kinesis';

async function putRecords() {
  const command = new PutRecordsCommand({
    StreamName: 'my-stream',
    Records: [
      { PartitionKey: 'user-1', Data: Buffer.from(JSON.stringify({ action: 'login' })) },
      { PartitionKey: 'user-2', Data: Buffer.from(JSON.stringify({ action: 'click' })) },
      { PartitionKey: 'user-1', Data: Buffer.from(JSON.stringify({ action: 'purchase' })) },
    ],
  });

  const response = await client.send(command);
  console.log('FailedRecordCount:', response.FailedRecordCount);
}
```

### Consumer

```ts
import {
  KinesisClient,
  GetShardIteratorCommand,
  GetRecordsCommand,
} from '@aws-sdk/client-kinesis';

const client = new KinesisClient({ region: 'ap-northeast-2' });

async function consumeRecords() {
  // Shard Iterator 획득
  const iteratorResponse = await client.send(new GetShardIteratorCommand({
    StreamName: 'my-stream',
    ShardId: 'shardId-000000000000',
    ShardIteratorType: 'LATEST', // TRIM_HORIZON, AT_TIMESTAMP 등
  }));

  let shardIterator = iteratorResponse.ShardIterator;

  // 레코드 폴링
  while (shardIterator) {
    const recordsResponse = await client.send(new GetRecordsCommand({
      ShardIterator: shardIterator,
      Limit: 100,
    }));

    for (const record of recordsResponse.Records ?? []) {
      const data = JSON.parse(Buffer.from(record.Data!).toString());
      console.log('Record:', data, 'SequenceNumber:', record.SequenceNumber);
    }

    shardIterator = recordsResponse.NextShardIterator;

    // 읽기 제한 초과 방지를 위한 대기
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}
```

## Lambda 트리거 연동

Kinesis는 Lambda의 이벤트 소스로 직접 연동할 수 있다. 배치 단위로 레코드를 Lambda에 전달한다.

```ts
import { KinesisStreamEvent } from 'aws-lambda';

export const handler = async (event: KinesisStreamEvent) => {
  for (const record of event.Records) {
    const data = JSON.parse(
      Buffer.from(record.kinesis.data, 'base64').toString()
    );
    console.log('Processing:', data);
    console.log('PartitionKey:', record.kinesis.partitionKey);
    console.log('SequenceNumber:', record.kinesis.sequenceNumber);
  }
};
```

## 아키텍처 패턴

### 실시간 로그 수집 파이프라인

```
App Servers → Kinesis Data Streams → Lambda → OpenSearch
                                   → Firehose → S3 (아카이브)
```

### 실시간 분석

```
IoT Devices → Kinesis Data Streams → Kinesis Data Analytics (Flink)
                                   → DynamoDB (실시간 집계)
```

### 이벤트 소싱

```
Microservices → Kinesis Data Streams → Consumer A (주문 서비스)
                                     → Consumer B (알림 서비스)
                                     → Firehose → S3 (이벤트 저장소)
```

## 운영 시 고려사항

- **Shard 수 계획**: 예상 쓰기 처리량(MB/s) ÷ 1MB = 최소 Shard 수. 여유를 두고 설정한다.
- **Hot Shard 방지**: Partition Key를 고르게 분산하여 특정 Shard에 트래픽이 집중되지 않도록 한다.
- **읽기 제한**: 공유 모드에서 Shard당 `GetRecords`는 초당 5회로 제한된다. Consumer가 많으면 Enhanced Fan-Out을 고려한다.
- **모니터링**: CloudWatch에서 `IncomingRecords`, `GetRecords.IteratorAgeMilliseconds`(Consumer Lag), `WriteProvisionedThroughputExceeded` 등을 모니터링한다.
- **비용 최적화**: 트래픽 패턴에 따라 Provisioned/On-Demand 모드를 선택하고, 불필요한 Shard는 병합한다.
- **KCL(Kinesis Client Library)**: 복잡한 Consumer 로직에는 KCL을 사용하여 체크포인팅, Shard 재배치 등을 자동화한다.
