# Amazon SQS (Simple Queue Service)

## 개요

Amazon SQS는 AWS에서 제공하는 완전관리형(Fully Managed) 메세지 큐 서비스다. 서버를 직접 운영할 필요 없이 분산 시스템 간의 메세지를 안정적으로 전달할 수 있으며, 자동으로 확장되어 처리량에 대한 걱정 없이 사용할 수 있다.

## 핵심 개념

### Queue 유형

SQS는 두 가지 유형의 큐를 제공한다.

**Standard Queue (표준 큐)**
- 거의 무제한의 처리량을 제공한다.
- 최소 1회 전달(At-Least-Once Delivery)을 보장하며, 간혹 메세지가 중복 전달될 수 있다.
- 최선의 순서(Best-Effort Ordering)를 제공하지만 엄격한 순서 보장은 하지 않는다.

**FIFO Queue**
- 메세지 순서를 엄격히 보장한다.
- 정확히 1회 전달(Exactly-Once Processing)을 보장한다.
- 초당 최대 300건 (배치 사용 시 3,000건)의 처리량 제한이 있다.
- 큐 이름이 `.fifo`로 끝나야 한다.

### Message

- 최대 256KB 크기의 메세지를 전송할 수 있다.
- 큰 데이터는 S3에 저장하고 참조 URL을 메세지로 전달하는 패턴을 사용한다.
- 메세지 속성(Attributes)을 통해 메타데이터를 첨부할 수 있다.

### Visibility Timeout

Consumer가 메세지를 가져가면 해당 메세지는 다른 Consumer에게 보이지 않는 상태가 된다. 이 시간 내에 처리를 완료하고 삭제하지 않으면 메세지가 다시 큐에 나타난다.

- 기본값: 30초
- 최대: 12시간
- 처리 시간에 맞게 적절히 설정해야 한다.

### Dead Letter Queue (DLQ)

처리에 반복적으로 실패한 메세지를 별도의 큐로 이동시키는 기능이다. `maxReceiveCount`를 설정하여 지정된 횟수만큼 실패하면 DLQ로 이동된다.

### Long Polling

메세지가 없을 때 빈 응답을 반복하는 대신, 메세지가 도착할 때까지 최대 20초간 대기하는 방식이다. 불필요한 API 호출과 비용을 줄일 수 있다.

## SQS vs SNS vs EventBridge

| 항목 | SQS | SNS | EventBridge |
|------|-----|-----|-------------|
| 패턴 | Point-to-Point | Pub/Sub | Event Bus |
| 소비자 | 1개의 Consumer가 소비 | 다수의 Subscriber에 전달 | 규칙 기반 라우팅 |
| 보존 | 최대 14일 보존 | 보존 없음 (즉시 전달) | 아카이브 가능 |
| 순서 | FIFO 큐로 보장 | FIFO Topic 지원 | 순서 미보장 |
| 적합한 케이스 | 작업 큐, 비동기 처리 | 알림, 팬아웃 | 이벤트 기반 아키텍처 |

SNS + SQS 조합으로 팬아웃 패턴을 구현하는 것이 일반적이다.

## 주요 특징

- **완전관리형**: 인프라 운영이 필요 없으며, AWS가 가용성과 확장성을 관리한다.
- **자동 확장**: 메세지 양에 따라 자동으로 확장된다.
- **보안**: IAM 정책, SQS 정책, SSE(Server-Side Encryption)를 통한 암호화를 지원한다.
- **비용**: 요청 기반 과금 (100만 요청당 과금), 프리 티어로 월 100만 건 무료.

## AWS SDK (Node.js) 사용 예시

### 설치

```bash
npm install @aws-sdk/client-sqs
```

### Producer

```ts
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

const client = new SQSClient({ region: 'ap-northeast-2' });

async function sendMessage() {
  const command = new SendMessageCommand({
    QueueUrl: 'https://sqs.ap-northeast-2.amazonaws.com/123456789/my-queue',
    MessageBody: JSON.stringify({ userId: 1, action: 'signup' }),
    MessageAttributes: {
      EventType: { DataType: 'String', StringValue: 'UserCreated' },
    },
  });

  const response = await client.send(command);
  console.log('MessageId:', response.MessageId);
}
```

### Consumer

```ts
import { SQSClient, ReceiveMessageCommand, DeleteMessageCommand } from '@aws-sdk/client-sqs';

const client = new SQSClient({ region: 'ap-northeast-2' });
const queueUrl = 'https://sqs.ap-northeast-2.amazonaws.com/123456789/my-queue';

async function pollMessages() {
  const receiveCommand = new ReceiveMessageCommand({
    QueueUrl: queueUrl,
    MaxNumberOfMessages: 10,
    WaitTimeSeconds: 20, // Long Polling
  });

  const response = await client.send(receiveCommand);

  for (const message of response.Messages ?? []) {
    console.log('Received:', message.Body);

    // 처리 완료 후 삭제
    await client.send(new DeleteMessageCommand({
      QueueUrl: queueUrl,
      ReceiptHandle: message.ReceiptHandle!,
    }));
  }
}
```

## Lambda 트리거 연동

SQS는 AWS Lambda의 이벤트 소스로 직접 연동할 수 있어 서버리스 아키텍처에서 매우 유용하다.

```ts
// Lambda Handler
export const handler = async (event: SQSEvent) => {
  for (const record of event.Records) {
    const body = JSON.parse(record.body);
    console.log('Processing:', body);
    // 처리 로직
  }
};
```

## 운영 시 고려사항

- **Visibility Timeout 설정**: 작업 처리 시간보다 충분히 길게 설정해야 중복 처리를 방지할 수 있다.
- **DLQ 설정**: 반드시 Dead Letter Queue를 구성하여 실패 메세지를 추적한다.
- **Long Polling 사용**: Short Polling 대신 Long Polling을 사용하여 비용을 절감한다.
- **배치 처리**: `SendMessageBatch`/`ReceiveMessage(MaxNumberOfMessages)`를 활용하여 API 호출 수를 줄인다.
- **멱등성**: Standard Queue의 중복 전달에 대비하여 멱등성을 보장하는 로직을 구현한다.
- **모니터링**: CloudWatch에서 `ApproximateNumberOfMessagesVisible`, `ApproximateAgeOfOldestMessage` 등의 지표를 모니터링한다.
