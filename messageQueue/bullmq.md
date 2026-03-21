# BullMQ

## 개요

BullMQ는 Node.js에서 고성능 백그라운드 작업 처리와 스케줄링을 제공하는 Redis 기반 큐 시스템이다. Bull의 차세대 버전으로, 다중 큐, 작업 간 의존성(Flows), 향상된 이벤트 처리, 더 정교한 반복 작업(Repeatable Jobs) 등 현대적 기능을 제공한다.

## 핵심 개념

### Queue

작업(Job)을 추가하는 엔티티다. 생산자(Producer)가 사용하며, 이름으로 구분된다.

### Worker

Queue의 Job을 소비(Consume)하고 실제 로직을 실행하는 주체다.

### Job

실행할 단위 작업이다. 이름(name), 데이터(data), 옵션(options)을 포함한다.

### Flow (Dependencies)

작업 간 의존 관계를 정의하여 순서/병렬 수행을 제어한다. `FlowProducer`를 통해 부모-자식 관계의 작업 트리를 구성할 수 있다.

### Repeatable Job

크론 패턴이나 고정 딜레이로 반복 실행되는 작업이다.

## Bull vs BullMQ 차이점

| 항목 | Bull | BullMQ |
|------|------|--------|
| 아키텍처 | 단일 큐 중심 설계 | 다중 큐 및 확장성 개선 |
| 기능 | 기본 우선순위, 재시도, 지연 | + 작업 의존성(Flow), 개선된 Rate Limit |
| 유지보수 | 제한적, 신규 기능 둔화 | 활발한 개발과 개선 |
| Redis | Redis 사용 | Redis 5+ (권장 6+) |
| NestJS | `@nestjs/bull` | `@nestjs/bullmq` |
| Processor | `@Process()` 데코레이터 | `WorkerHost` 상속 |

신규 프로젝트라면 BullMQ 사용을 권장한다.

## 설치

```bash
npm install bullmq ioredis
# NestJS 사용 시
npm install @nestjs/bullmq bullmq ioredis
```

## 기본 사용법 (Standalone)

### Producer

```ts
import { Queue } from 'bullmq';

const queue = new Queue('my-queue', {
  connection: { host: '127.0.0.1', port: 6379 },
});

await queue.add('job-name', { foo: 'bar' }, {
  attempts: 3,
  backoff: { type: 'exponential', delay: 1000 },
});
```

### Worker

```ts
import { Worker } from 'bullmq';

const worker = new Worker('my-queue', async (job) => {
  console.log(`Processing ${job.name}: ${JSON.stringify(job.data)}`);
  // 작업 처리 로직
  return { result: 'done' };
}, {
  connection: { host: '127.0.0.1', port: 6379 },
  concurrency: 5,
});

worker.on('completed', (job, result) => {
  console.log(`Job ${job.id} completed with result: ${JSON.stringify(result)}`);
});

worker.on('failed', (job, err) => {
  console.error(`Job ${job?.id} failed: ${err.message}`);
});
```

## NestJS에서 BullMQ 사용

### 모듈 설정

```ts
// app.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';

@Module({
  imports: [
    BullModule.forRoot({
      connection: {
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: Number(process.env.REDIS_PORT) || 6379,
      },
    }),
  ],
})
export class AppModule {}
```

### 큐 등록

```ts
// mail/mail.module.ts
import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { MailService } from './mail.service';
import { MailProcessor } from './mail.processor';

@Module({
  imports: [
    BullModule.registerQueue({ name: 'mail-queue' }),
  ],
  providers: [MailService, MailProcessor],
  exports: [MailService],
})
export class MailModule {}
```

### Producer (Service)

```ts
// mail/mail.service.ts
import { Injectable } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

@Injectable()
export class MailService {
  constructor(@InjectQueue('mail-queue') private readonly queue: Queue) {}

  async enqueueMail(to: string, subject: string, body: string) {
    return this.queue.add('send-mail', { to, subject, body }, {
      attempts: 5,
      backoff: { type: 'exponential', delay: 2000 },
      removeOnComplete: { age: 86400, count: 1000 },
      removeOnFail: 1000,
    });
  }
}
```

### Processor (Worker)

```ts
// mail/mail.processor.ts
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';

@Processor('mail-queue')
export class MailProcessor extends WorkerHost {
  private readonly logger = new Logger(MailProcessor.name);

  async process(job: Job): Promise<any> {
    switch (job.name) {
      case 'send-mail':
        const { to, subject, body } = job.data;
        this.logger.log(`Sending mail to ${to}: ${subject}`);
        // 실제 메일 발송 로직
        return { sent: true };
      default:
        this.logger.warn(`Unhandled job: ${job.name}`);
    }
  }

  @OnWorkerEvent('completed')
  onCompleted(job: Job, result: any) {
    this.logger.log(`Job ${job.id} completed`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, err: Error) {
    this.logger.error(`Job ${job?.id} failed: ${err.message}`);
  }
}
```

## 주요 Job 옵션

| 옵션 | 설명 |
|------|------|
| `attempts` | 실패 시 최대 재시도 횟수 |
| `backoff` | 재시도 대기 정책 (`{ type: 'fixed' \| 'exponential', delay: ms }`) |
| `delay` | 밀리초 지연 후 실행 |
| `priority` | 우선순위 (1이 가장 높음) |
| `timeout` | 작업 타임아웃 (ms) |
| `jobId` | 사용자 지정 고유 Job ID |
| `removeOnComplete` | 완료된 Job 삭제 정책 |
| `removeOnFail` | 실패한 Job 삭제 정책 |
| `lifo` | true면 큐 앞에서 실행 (스택 동작) |
| `repeat` | 반복 작업 설정 (크론/고정 주기) |

## 주요 기능

### 지연/예약 작업

```ts
await queue.add('delayed-job', data, { delay: 10_000 }); // 10초 후 실행
```

### 반복 작업 (스케줄링)

```ts
await queue.add('report', {}, {
  repeat: { pattern: '0 9 * * 1' }, // 매주 월요일 09:00
});

await queue.add('heartbeat', {}, {
  repeat: { every: 60_000 }, // 매 1분
});
```

### 작업 의존성 (Flow)

```ts
import { FlowProducer } from 'bullmq';

const flow = new FlowProducer({ connection: { host: '127.0.0.1', port: 6379 } });

await flow.add({
  name: 'aggregate',
  queueName: 'pipeline',
  data: {},
  children: [
    { name: 'process-1', queueName: 'pipeline', data: { id: 1 } },
    { name: 'process-2', queueName: 'pipeline', data: { id: 2 } },
  ],
});
```

### Rate Limiting

```ts
// Worker 레벨에서 설정
const worker = new Worker('api-queue', processor, {
  limiter: { max: 100, duration: 60_000 }, // 1분에 최대 100개
});
```

## Kafka vs BullMQ 비교

| 항목 | Kafka | BullMQ |
|------|-------|--------|
| 기반 | 분산 로그 (디스크) | Redis (인메모리) |
| 처리량 | 초당 수백만 건 | 초당 수천~수만 건 |
| 메세지 보존 | 장기 보존 (설정 기반) | 처리 후 삭제 (보존 옵션 제공) |
| 재처리 | Offset 기반으로 용이 | 제한적 |
| 작업 스케줄링 | 미지원 (별도 도구 필요) | 크론/지연/반복 내장 |
| 작업 의존성 | 미지원 | Flow로 부모-자식 의존성 지원 |
| 인프라 | Kafka 클러스터 운영 필요 | Redis만 필요 |
| 적합한 케이스 | 대용량 이벤트 스트리밍 | 백그라운드 작업, 작업 큐 |

## 모니터링

### Bull Board

```bash
npm install @bull-board/express @bull-board/api
```

```ts
import { createBullBoard } from '@bull-board/api';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';
import { ExpressAdapter } from '@bull-board/express';

const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath('/queues');

createBullBoard({
  queues: [new BullMQAdapter(queue)],
  serverAdapter,
});

app.use('/queues', serverAdapter.getRouter());
```

## 운영 시 고려사항

- **Redis 가용성**: Redis 장애 시 전체 큐 시스템이 중단되므로 Redis Sentinel이나 Cluster 구성을 권장한다.
- **동시성 튜닝**: 외부 API 호출 등 I/O 바운드 작업은 동시성을 높이고, CPU 바운드 작업은 낮게 설정한다.
- **Job 보존 정책**: `removeOnComplete`/`removeOnFail`을 설정하여 Redis 메모리 사용량을 관리한다.
- **멱등성**: 재시도로 인한 중복 실행에 대비하여 멱등성 키를 도입한다.
- **큐 분리**: 기능별로 큐를 분리하여 장애를 격리한다.
- **보안**: Redis 비밀번호, TLS, 네트워크 접근 제어를 적용한다.
