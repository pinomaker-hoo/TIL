# SSE

## 개요

SSE에 대한 학습을 진행 합니다.

## SSE

SSE는 Server Side Event의 약자로, Server에서 Client에게 Event를 발행할 수 있는 기술이다.

서비스를 구성할 때 실시간으로 처리해야하는 작업들이 있는 데 가장 대표적으로는 채팅, 알림이 있다. 채팅의 경우는 양방향으로 실시간 통신이 되어야하기에 Socket을 이용하여 구현하는 것이 일반적이지만 알림의 경우는 서버에서 알림이 최신화되었는 지만 알려주면 되기에 단방향 통신으로도 처리 할 수 있다. 보통은 App에서는 App Push를 이용하거나 Web에서는 Web Push를 이용한다. 혹은 Socket을 이용하여 구성하거나 Polling 기법을 사용하여 구현할 수도 있다.

하지만 SSE를 사용하면 비교적 쉽고 효율적으로 처리가 가능하다.

### 통신 프로토콜

SSE의 경우는 HTTP 프로토콜을 사용한다.

![Image](https://github.com/user-attachments/assets/925e89c4-0496-4a70-a2c3-f393c9407367)

Client에서 HTTP GET 요청을 통해 서버와의 Connection을 연결하고 Server에서는 연결된 Client를 대상으로 Event를 발행할 수 있으며, Client는 다시 연결을 끊을 수 있다.

단방향 통신만 지원하는 단점이 있지만 외부 라이브러리나 Socket 없이 서버에서 이벤트를 발행할 수 있는 점은 매우 좋은 부분이라고 생각한다.

### NestJS에서 SSE 구현

NestJS 공식 문서에는 SSE에 대한 구현 방법을 알려준다.

Link : https://docs.nestjs.com/techniques/server-sent-events

먼저 연결을 생성하기 위한 Controller를 구현한다.

```typescript
import { Sse, MessageEvent, Controller } from "@nestjs/common";
import { interval, map, Observable } from "rxjs";

@Controller({ version: "1", path: "/app" })
export class AppController {
  @Sse("sse")
  sse(): Observable<MessageEvent> {
    return interval(1000).pipe(map((_) => ({ data: { hello: "world" } })));
  }
}
```

문서에 따르면 무조건 리턴 타입은 Observable이어야 한다고한다. 그리고 Postman을 이용하여 해당 endpoint에 GET 요청을 보내면 아래와 같이 연결이 생기며 1초에 1번씩 아래 데이터가 반환되고 있음을 확인할 수 있다.

```json
{
  "hello": "world"
}
```

<img width="1342" alt="Image" src="https://github.com/user-attachments/assets/0344372b-2a9e-4427-a0d4-f485449ee31f" />

<br />

비즈니스 로직 내에서 사용자에게 Message를 발송하고 싶다면 EventEmitter2를 사용하면 된다. 또한 SSE API 쪽에서는 from Event를 사용하여, Event를 수신하면 메세지를 발송하게 처리한다.

```typescript
export class AppService {
  constructor(private readonly eventEmitter: EventEmitter2) {}
  public async push(event: { message: string; userId: number }): Promise<void> {
    this.eventEmitter.emit("sse.push", event);
  }
}

@Controller({ version: "1", path: "/app" })
export class AppController {
  @Sse("sse")
  sse(): Observable<MessageEvent> {
    return fromEvent(this.eventEmitter, "ses.push").pipe(map((_data) => _data));
  }
}
```

만약 특정 유저에게만 발송을 하고 싶다면, Request에 유저 식별값을 받아서 아래와 같이 처리한다.

```typescript
@Controller({ version: "1", path: "/app" })
export class AppController {
  @Sse("sse/:userId")
  sse(@Param("userId") userId: number): Observable<MessageEvent> {
    return fromEvent(this.eventEmitter, "sse").pipe(
      map((_data) => {
        if (_data.userId == userId) {
          return _data;
        }
      })
    );
  }
}
```
