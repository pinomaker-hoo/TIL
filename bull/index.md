# Bull

## 개요

Bull MQ에 대한 학습을 진행합니다.

## Bull

![Image](https://github.com/user-attachments/assets/65c599b7-ca50-4430-92ec-bb6decd46192)

Bull은 NodeJS 환경에서 Queue 시스템을 관리하는 라이브러리로, 백그라운드 작업을 처리하기 위해 사용 가능하다. Redis를 기반으로 작업을 Queue에 넣어 처리한다.

Bull에서는 아래 작업들을 처리 가능하다.

- 작업 큐 관리 : 작업을 넣고 순차적으로 처리 가능하다.
- 작업 우선 순위 설정 : 여러 작업을 큐에 넣을 때 원하는 순서대로 넣어 순차적으로 처리한다.
- 재시도 : 실패한 작업을 큐에 넣어 재시도 처리할 수 있다.
- 작업 이벤트 관리 : 작업의 진행 상태나 실패 완료 등의 이벤트 처리가 가능하다.
- 작업 완료 및 실패 관리 : 작업이 성공적으로 완료되거나 실패할 경우 그에 대한 처리가 가능하다.

하지만 Bull의 경우는 단일 큐 시스템을 지원하기에 현재는 차세대 버전인 BullMQ를 많이 사용한다.

## BullMQ

![Image](https://github.com/user-attachments/assets/438babdb-ea44-4dc6-8413-77e9193c10c9)

BullMQ는 Bull의 차세대 버전으로 단일 큐를 관리하던 Bull과 달리 여러 큐를 관리할 수 있고 더 다양한 기능을 지원합니다.

- Multi-Queue : 기존에 단일 큐를 지원하던 것과 달리 다중 큐를 동시에 관리하여 다양한 작업을 동시에 처리 가능
- Job Relationships : 작업 간의 관계를 정의할 수 있어, 작업 간의 의존성이나 Rate Limiting을 설정하여 일정량의 작업을 초과하지 않게 조절 가능하다.
- 성능 : Bull에 비하여 성능이 더 좋아짐
- 정확한 스케줄링 : Repeatable Jobs를 이용하여 스케줄링 기능에 대해 처리 가능하다.
- Redis Streams : Redis Streams를 활용하여 더 높은 성능과 확장성으로 구현 가능하다.

### NestJS에서 BullMQ 활용하기

NestJS에서 1,000명에게 메일을 발송하는 API를 구현한다고 가정해보자. 그러면 일반적으로는 아래 과정을 거친다.

1. 메일 대상자들을 조회한다.
2. 반복문 혹은 Promise.ALL를 사용하여 각 대상자에게 메일을 발송한다.

위의 과정으로 API를 구성하면 메일 발송 대상자가 많아질수록 API 응답 속도가 느려질 수 밖에 없다. 메일 발송 API는 꼭 모든 메일을 발송하고나서 응답을 보낼 필요는 없다. 메일 서버에 따라서 레이턴시가 발생할 수 있기에 BullMQ를 사용하여 효율적으로 처리 가능하다.

```typescript

// Before
public async sendMail(emailList:string[], subject : string, body : string) : Promise<void> {
    for (const email of emailList) {
        this.mailService.send(email, subject, body);
    }
}

// After
public async sendMail(emailList:string[], subject : string, body : string) : Promise<void> {
     await this.queue.add('mail', {
        emailList, subject, body
     });
}

@Processor('mail-queue')
export default class MailConsumer {
  constructor(private readonly mailService: MailService) {}
  private logger = new Logger(MailConsumer.name);

  @Process('mail')
  async handleJob(job: Job<MailTriggetEvent>) {
    const event = job.data;
    this.logger.log(`Consume Mail Event : ${JSON.stringify(event)}`);
    for (const email of emailList) {
        this.mailService.send(email, subject, body);
    }
  }
}


```
