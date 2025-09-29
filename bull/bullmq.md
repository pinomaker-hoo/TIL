# BullMQ (NestJS)

## 개요

BullMQ는 Node.js에서 고성능 백그라운드 작업 처리와 스케줄링을 제공하는 Redis 기반 큐 시스템입니다. Bull의 차세대 버전으로, 다중 큐, 작업 간 의존성(Flows), 향상된 이벤트 처리, 더 정교한 반복 작업(Repeatable jobs) 등 현대적 기능을 제공합니다. 본 문서는 NestJS 환경을 기준으로 Bull과 BullMQ의 차이점, NestJS 통합 방법, 실전 패턴과 베스트 프랙티스를 정리합니다.

## Bull vs BullMQ 차이점

- 성능과 아키텍처
  - Bull: 단일 큐 중심 설계, 오래된 코드베이스. 이벤트 핸들링과 확장성에서 제약이 있음.
  - BullMQ: 다중 큐 및 확장성 개선, 더 정교한 스케줄링과 작업 종속성(Flows) 지원.
- 기능
  - Bull: 기본 우선순위, 재시도, 지연, 반복 작업 지원.
  - BullMQ: 위 기능 + 작업 간 의존성(FlowProducer), 더 풍부한 이벤트, 개선된 Rate Limit/Concurrency, Job Lifecycle 관리 강화.
- 생태계 및 유지보수
  - Bull: 유지보수 제한적, 신규 기능 추가 둔화.
  - BullMQ: 활발한 개발과 개선 추세.
- Redis 요구사항
  - 두 라이브러리 모두 Redis를 사용. BullMQ는 Redis 5 이상(권장 6+)에서 가장 안정적으로 동작합니다.
- NestJS 통합
  - Bull: `@nestjs/bull`
  - BullMQ: `@nestjs/bullmq` (NestJS v9/10 이상 권장)

요약: 신규 프로젝트나 마이그레이션을 고려한다면 BullMQ 사용을 권장합니다.

## 설치

```bash
npm i @nestjs/bullmq bullmq ioredis
# 또는
yarn add @nestjs/bullmq bullmq ioredis
```

- Redis는 별도 설치가 필요합니다. 로컬 개발은 Docker 사용을 권장합니다.

```bash
docker run -p 6379:6379 --name redis -d redis:7
```

## 기본 개념 정리

- Queue: 작업(Job)을 추가하는 엔티티. 생산자(Producer)가 사용.
- Worker: Queue의 Job을 소비(Consume)하고 실제 로직을 실행.
- Job: 실행할 단위 작업. 이름(name), 데이터(data), 옵션(options)을 포함.
- Flow(Dependencies): 작업 간 의존 관계를 정의하여 순서/병렬 수행을 제어.
- Repeatable Job: 크론 패턴이나 고정 딜레이로 반복 실행되는 작업.
- Events: 작업 진행, 완료, 실패 등의 이벤트 스트림.

## NestJS에서 BullMQ 시작하기

### 1) 설정 모듈 구성

`@nestjs/bullmq`의 `BullModule`을 사용합니다. 보통 `ConfigModule`과 함께 연결합니다.

```ts
// app.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { BullModule } from '@nestjs/bullmq';
import { MailModule } from './mail/mail.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    BullModule.forRoot({
      connection: {
        host: process.env.REDIS_HOST || '127.0.0.1',
        port: Number(process.env.REDIS_PORT) || 6379,
        // password: process.env.REDIS_PASSWORD,
        // tls: {}
      },
    }),
    MailModule,
  ],
})
export class AppModule {}
```

### 2) 큐 등록과 Producer 작성

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

```ts
// mail/mail.service.ts
import { Injectable, Logger } from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';

interface SendMailPayload {
  subject: string;
  body: string;
  recipients: string[];
}

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);

  constructor(@InjectQueue('mail-queue') private readonly queue: Queue) {}

  async enqueueBulkMail(payload: SendMailPayload) {
    // 이름이 있는 잡으로 추가 ("send-mail")
    // 우선순위, 지연, 재시도, 백오프 등 옵션을 필요에 따라 부여
    return this.queue.add('send-mail', payload, {
      attempts: 5, // 최대 5회 재시도
      backoff: { type: 'exponential', delay: 2000 },
      removeOnComplete: { age: 24 * 3600, count: 1000 },
      removeOnFail: 1000,
      priority: 1,
    });
  }
}
```

### 3) Processor(Worker) 작성

BullMQ에서는 `WorkerHost`를 상속하거나 데코레이터 기반 이벤트를 함께 사용할 수 있습니다.

```ts
// mail/mail.processor.ts
import { Processor, WorkerHost, OnWorkerEvent } from '@nestjs/bullmq';
import { Job } from 'bullmq';
import { Logger } from '@nestjs/common';

@Processor('mail-queue')
export class MailProcessor extends WorkerHost {
  private readonly logger = new Logger(MailProcessor.name);

  // 모든 Job은 여기서 처리됩니다. job.name으로 분기하세요.
  async process(job: Job): Promise<any> {
    this.logger.log(`Processing job: ${job.name} (id: ${job.id})`);

    switch (job.name) {
      case 'send-mail':
        const { subject, body, recipients } = job.data as {
          subject: string; body: string; recipients: string[];
        };
        // 실제 메일 발송 로직 (예: 외부 MailService 호출)
        for (const to of recipients) {
          // await this.mailer.send(to, subject, body);
          this.logger.log(`Send mail to ${to}: ${subject}`);
        }
        return { count: recipients.length };

      default:
        this.logger.warn(`Unhandled job name: ${job.name}`);
        return null;
    }
  }

  // 주요 이벤트 리스너 예시
  @OnWorkerEvent('completed')
  onCompleted(job: Job, result: any) {
    this.logger.log(`Job completed: ${job.id}, result: ${JSON.stringify(result)}`);
  }

  @OnWorkerEvent('failed')
  onFailed(job: Job, err: Error) {
    this.logger.error(`Job failed: ${job?.id} - ${err.message}`);
  }
}
```

## 핵심 기능 심화

### 어노테이션(데코레이터) 정리 (NestJS BullMQ)

- `@Processor(queueName: string)`
  - 해당 클래스가 특정 큐의 Worker임을 선언합니다. 클래스는 `WorkerHost`를 상속하여 `process(job)` 메서드를 구현합니다.

- `@OnWorkerEvent(event: WorkerListener)`
  - Worker 수명주기 이벤트를 구독합니다.
  - 주요 이벤트: `active`, `completed`, `failed`, `progress`, `waiting`, `drained`, `stalled`, `paused`, `resumed`, `removed`, `error` 등
  - 시그니처 예시: `onCompleted(job: Job, result: any) {}`, `onFailed(job: Job, err: Error) {}`

- `@InjectQueue(queueName: string)`
  - Producer(Service/Controller 등)에서 `Queue` 인스턴스를 주입합니다.

- `@InjectQueueEvents?(queueName: string)`
  - 선택적. `QueueEvents` 인스턴스를 주입하여 글로벌 이벤트 스트림을 구독하고 싶을 때 사용합니다. (버전에 따라 제공 여부가 다를 수 있습니다. 미제공 시 직접 `new QueueEvents()` 사용)

참고: Bull(구버전)의 `@Process()` 데코레이터는 BullMQ 패키지에서는 사용하지 않습니다. BullMQ에서는 `WorkerHost`의 `process()`를 사용하세요.

---

### 옵션 정리

아래 옵션들은 BullMQ의 일반적인 스펙을 기준으로 정리했으며, 실제 사용 버전에 따라 일부 필드나 동작이 상이할 수 있습니다. 운영 전 해당 버전의 공식 타입/문서를 확인하세요.

#### 1) Job 추가 시 옵션 (`Queue.add(name, data, options)`의 `JobsOptions`)

- `attempts: number`
  - 실패 시 최대 재시도 횟수

- `backoff: number | { type: 'fixed' | 'exponential'; delay: number }`
  - 재시도 사이의 대기 정책

- `delay: number`
  - 밀리초 지연 후 실행

- `priority: number`
  - 숫자가 낮을수록 높은 우선순위 (1이 가장 높음)

- `lifo: boolean`
  - true면 큐 뒤가 아닌 앞에서 실행 (스택처럼 동작)

- `timeout: number`
  - 작업 타임아웃(ms). 초과 시 실패 처리

- `jobId: string`
  - 사용자가 지정하는 고유 Job ID (중복 제출 방지 등)

- `removeOnComplete: boolean | number | { age?: number; count?: number }`
  - 완료된 Job 자동 삭제 정책
  - `true` 또는 숫자(최대 개수), 혹은 `age(초 단위), count` 기반 보존 정책

- `removeOnFail: boolean | number`
  - 실패 Job 자동 삭제 정책

- `stackTraceLimit: number`
  - 저장할 스택 트레이스의 최대 프레임 수

- `repeat: RepeatOptions`
  - 반복 작업 설정 (스케줄링). 아래 RepeatOptions 참조

- `parent: { id: string; queue: string }`
  - 부모 작업 지정 (Flow/의존성 처리용)

- `keepLogs?: number`
  - 로그 보존 개수 제한(버전에 따라 상이)

주의: 레이트 리미트는 보통 큐/워커 레벨에서 설정합니다. (일부 버전에서 per-job 리미트 옵션이 노출될 수 있으나 일반적이지 않습니다)

#### RepeatOptions (반복 작업)

- `pattern?: string`
  - cron 표현식 (예: `0 9 * * 1`)

- `every?: number`
  - 고정 주기(ms)

- `tz?: string`
  - 타임존(예: `Asia/Seoul`)

- `startDate?: number | Date`
  - 스케줄 시작 시점

- `endDate?: number | Date`
  - 스케줄 종료 시점

- `limit?: number`
  - 최대 반복 횟수

- `jobId?: string`
  - 반복 Job 키 산정에 포함될 ID. 특정 반복 작업을 식별/제거할 때 유용

- `key?: string`
  - 내부 repeat key 지정(특수 케이스)

#### 2) Queue 레벨 옵션 (`BullModule.registerQueue` 또는 `new Queue(name, opts)`의 `QueueOptions`)

- `connection`
  - Redis 연결 정보 `{ host, port, password, tls, ... }`

- `prefix?: string`
  - Redis 키 prefix (다중 환경 분리)

- `defaultJobOptions?: JobsOptions`
  - 해당 큐에 추가되는 Job의 기본 옵션 (attempts, backoff 등)

- `limiter?` (일반적으로 Queue 혹은 Worker 측에서 설정)
  - 레이트 제한 설정 `{ max: number; duration: number; groupKey?: string }`
  - 특정 기간(`duration`) 동안 처리 가능한 최대 작업수(`max`)

- `streams?`
  - Redis Streams 관련 설정 (버전/내부 사용)

#### 3) Worker 옵션 (`WorkerHost`/`Worker` 생성 시)

- `concurrency?: number`
  - 동시에 처리할 작업 수 (기본 1)

- `connection`
  - Redis 연결 정보

- `lockDuration?: number`
  - Job 실행 중 Lock 유지 시간(ms). 오래 걸리는 작업은 충분히 크게 설정

- `lockRenewTime?: number`
  - Lock 자동 갱신 주기(ms)

- `stalledInterval?: number`
  - Stalled Job(진행 중 멈춤) 탐지 주기(ms)

- `maxStalledCount?: number`
  - Stalled로 판단 시 재시도 최대 횟수

- `autorun?: boolean`
  - Worker 생성 즉시 실행할지 여부

- `runRetryDelay?: number`
  - 에러 발생 후 재실행 간격(ms)

- `useWorkerThreads? / nodeOptions?`
  - 워커 스레드 사용 관련 설정(버전/환경에 따라)

- `prefix?: string`
  - 키 prefix (Queue와 일치시켜 환경 분리)

- `sharedConnection?: boolean`
  - 다른 인스턴스와 Redis 연결 공유 여부

#### 4) QueueEvents 옵션

- `connection`
  - Redis 연결

- `autorun?: boolean`
  - 이벤트 리스닝 자동 시작 여부

#### 5) Flow(의존성) 옵션 (`FlowProducer.add`)

- 부모 작업 정의: `{ name, queueName, data, opts, children: FlowChild[] }`
- 자식 작업(`children`)에도 동일 구조 사용 가능. 중첩 가능
- 각 작업의 `opts`는 `JobsOptions`와 동일 (attempts/backoff/repeat 등)

---

### 1) 재시도, 백오프, 우선순위, 동시성

- `attempts`: 실패 시 재시도 횟수
- `backoff`: 고정/지수 백오프 설정 `{ type: 'fixed'|'exponential', delay: ms }`
- `priority`: 낮을수록 높은 우선순위(1이 가장 높음)
- 동시성(Concurrency): `BullModule.registerQueue({ name, worker: { concurrency: N } })` 또는 별도 Worker 인스턴스 옵션으로 제어 가능

```ts
BullModule.registerQueue({
  name: 'mail-queue',
  // worker 옵션은 전역 혹은 개별 Worker 구성에서 설정 가능
  // worker: { concurrency: 5 },
});
```

### 2) 지연/예약 작업과 반복 작업(스케줄링)

- 지연 작업: `delay` 옵션 사용
- 반복 작업: `repeat` 옵션 사용 (크론 패턴 또는 every(ms))

```ts
await this.queue.add('send-digest', { /* data */ }, {
  delay: 10_000, // 10초 후 실행
});

await this.queue.add('send-report', { /* data */ }, {
  repeat: { pattern: '0 9 * * 1' }, // 매주 월요일 09:00
});

await this.queue.add('heartbeat', {}, { repeat: { every: 60_000 } }); // 매 1분
```

반복 작업은 Redis에 예약 키가 생성되며, 제거 시에는 `queue.removeRepeatable()` 또는 정확한 repeat 키를 사용해야 합니다.

### 3) 작업 의존성(Flows)과 배치 처리

`FlowProducer`를 사용하여 부모/자식 관계의 작업을 정의할 수 있습니다. 예: 대용량 CSV 처리 시, 1) 파싱 -> 2) 개별 레코드 처리(병렬) -> 3) 집계.

```ts
import { FlowProducer } from 'bullmq';

const flow = new FlowProducer({
  connection: { host: '127.0.0.1', port: 6379 },
});

await flow.add({
  name: 'parent',
  queueName: 'pipeline',
  data: {},
  children: [
    { name: 'child-1', queueName: 'pipeline', data: { id: 1 } },
    { name: 'child-2', queueName: 'pipeline', data: { id: 2 } },
  ],
});
```

NestJS 내에서는 FlowProducer를 별도 Provider로 등록해 주입하여 사용합니다.

```ts
@Module({
  providers: [
    {
      provide: FlowProducer,
      useFactory: () => new FlowProducer({
        connection: { host: '127.0.0.1', port: 6379 },
      }),
    },
  ],
  exports: [FlowProducer],
})
export class PipelineModule {}
```

### 4) Rate Limiting

너무 많은 작업이 동시에 실행되지 않도록 제한할 수 있습니다.

```ts
await this.queue.add('send-mail', data, {
  rateLimiter: {
    max: 100,     // 단위 시간 내 최대 100개
    duration: 60_000, // 1분
  },
});
```

또는 Worker 레벨에서 설정할 수 있습니다.

### 5) Job Lifecycle 관리와 보존 정책

- `removeOnComplete`/`removeOnFail`: 완료/실패된 Job 보존 수/기간 제어
- `keepJobs`: 특정 조건에서 Job을 보존해 디버깅 가능

운영 환경에서는 Redis 저장소 사용량을 고려하여 적절히 정리하는 것을 권장합니다.

## 관찰(Observability) 및 모니터링

- Bull Board: BullMQ를 지원하는 UI 대시보드.

```bash
npm i @bull-board/express
```

```ts
// main.ts (예시)
import { createBullBoard } from '@bull-board/api';
import { BullMQAdapter } from '@bull-board/api/bullMQAdapter';
import { ExpressAdapter } from '@bull-board/express';
import { Queue } from 'bullmq';

const serverAdapter = new ExpressAdapter();
serverAdapter.setBasePath('/queues');

const { addQueue, removeQueue, setQueues, replaceQueues } = createBullBoard({
  queues: [new BullMQAdapter(new Queue('mail-queue'))],
  serverAdapter,
});

app.use('/queues', serverAdapter.getRouter());
```

- 로깅: `@OnWorkerEvent`를 활용하여 `completed`, `failed`, `progress` 등의 이벤트를 수집해 APM 또는 로깅 시스템으로 전송합니다.

## 테스트 전략

- 단위 테스트: Producer 서비스는 Queue에 올바른 옵션으로 `add` 호출 여부를 검사합니다. Queue 인스턴스를 mock 처리.
- 통합 테스트: 테스트용 Redis를 띄워 실제 Worker가 Job을 처리하도록 검증 (+ 짧은 TTL과 작은 보존량 권장).
- E2E: 주요 시나리오(대량 작업, 실패/재시도, Rate Limit, Repeatable Job 생성/삭제)를 자동화.

```ts
// 예: Jest에서 Producer 단위 테스트
it('enqueueBulkMail should add job with retries and backoff', async () => {
  const add = jest.fn();
  const service = new MailService({ add } as any);
  await service.enqueueBulkMail({ subject: 's', body: 'b', recipients: ['a@a.com'] });
  expect(add).toHaveBeenCalledWith('send-mail', expect.any(Object), expect.objectContaining({ attempts: 5 }));
});
```

## 보안 고려사항

- Redis 접근 제어: 비밀번호, TLS, VPC/Subnet 제어, 보안 그룹/방화벽.
- 입력 데이터 검증: Job 데이터 스키마 검증(class-validator/DTO).
- 멱등성: 네트워크 오류/재시도로 중복 실행 가능. 멱등 키(idempotency key) 도입.
- 장애 복구: Worker 프로세스의 예외 처리와 알림 체계(예: 실패 임계치 초과 시 알림).

## 마이그레이션 노트 (Bull → BullMQ)

- 패키지 교체: `@nestjs/bull` → `@nestjs/bullmq`, `bull` → `bullmq`.
- Processor 방식: Bull의 `@Process`/`@Processor`에서 BullMQ의 `WorkerHost` 기반으로 전환.
- 옵션 차이: 반복 작업, 백오프, rate limit 옵션 스펙이 다를 수 있으니 Job 옵션을 점검.
- 데이터 호환: 기존 큐 데이터를 그대로 재사용하기보다, 배포 시점에 큐를 비우고 이관하는 전략을 권장.

## 운영 베스트 프랙티스

- 큐 분리: 기능별(메일, 보고서, 알림 등)로 큐를 분리하여 장애 격리.
- 동시성/RateLimit 튜닝: 외부 API 한도와 인프라 리소스를 고려해 점진적으로 조정.
- 반복 작업 키 관리: `queue.getRepeatableJobs()`로 스케줄 상태를 점검하고, 삭제 시 정확한 키 사용.
- 알람: 실패율 급증, 지연 급증, 대기열 증가 등의 지표에 대한 알림 구성.
- 배포 전략: Worker와 API를 별도 프로세스로 운영해 확장성과 안정성을 확보.

## 예시: 대량 메일 발송 API (요약)

```ts
// Controller (요약)
@Post('mail/send')
async send(@Body() dto: SendMailDto) {
  await this.mailService.enqueueBulkMail({
    subject: dto.subject,
    body: dto.body,
    recipients: dto.recipients,
  });
  return { status: 'queued' };
}
```

```ts
// Processor (요약)
@Processor('mail-queue')
export class MailProcessor extends WorkerHost {
  async process(job: Job) {
    if (job.name === 'send-mail') {
      // 실제 발송 로직
    }
  }
}
```

## 결론

BullMQ는 NestJS와 결합했을 때, 대량 작업 처리, 지연/반복 스케줄링, 작업 간 의존성 관리 등 백엔드에서 흔히 요구되는 비동기 처리 요구사항을 깔끔하게 해결합니다. 신규 프로젝트나 기존 Bull 기반 프로젝트의 현대화를 고려한다면 BullMQ 채택을 권장합니다.
