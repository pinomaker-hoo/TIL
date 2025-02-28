# NodeJS의 Non-Blocking I/O

```
참고자료

- https://medium.com/@vdongbin/node-js-%EB%8F%99%EC%9E%91%EC%9B%90%EB%A6%AC-single-thread-event-driven-non-blocking-i-o-event-loop-ce97e58a8e21

- https://velog.io/@tkppp-dev/%EC%99%9C-Node.js%EB%8A%94-%EC%9E%90%EB%B0%94%EB%B3%B4%EB%8B%A4-%EB%B9%A0%EB%A5%B8%EA%B0%80
```

<img src="https://github.com/user-attachments/assets/7eb9b966-bf92-4935-932c-3ac9f44c2cfa" width=600>

<br />

NodeJS는 Javascript를 브라우저 밖에서도 실행할 수 있는 런타임이다. NodeJS 공식 사이트에 들어가면 NodeJS에 대해 아래와 같이 작성되어있다.

```
Node.js는 비동기 이벤트 기반의 JavaScript 런타임으로, 확장 가능한 네트워크 애플리케이션을 구축하도록 설계되었습니다.
```

<br />

여기서 중요한 포인트는 비동기(Asynchronous), 이벤트 주도(Event-driven), Non-blocking I/O, 확장성 입니다.

<br />

NodeJS는 흔히 싱글 스레드이며, 하나의 스레드가 하나의 요청만을 처리합니다. 해당 요청이 수행될 때, 다른 요청이 함께 수행될 수 없고 이를 싱글 스레드 블로킹 모델이라고 한다. 진행되고 있는 요청이 예정되어 있는 요청을 블로킹하기 때문이다. 싱글 스레드와 달리 멀티 스레드는 스레드풀에서 실행의 요청만큼 스레드를 매칭하여 작업을 수행하여 싱글 스레드보다 더 빠르고 좋아보이지만 효율성 측면에선 스레드풀에 스레드가 늘어날수록 CPU 비용을 소모하고, 요청이 적다면 놀고 있는 스레드가 발생하여 단점이 있다.

<br />

NodeJS는 싱글 스레드 논블로킹 모델로 구성되어있는 데, 하나의 스레드로 동작하지만 비동기 I/O 작업을 통해 요청들을 서로 블로킹하지 않아 많은 요청들을 비동기로 수행함으로써 싱글 스레드라고 하더라도 논블로킹이 가능하다. 또한 클러스터링을 통해 프로세스를 포크하여 멀티 스레드인것처럼 사용될 수 있어 확장성이 용이하다.

<br />

### NodeJS는 싱글 스레드인가?

NodeJS는 싱글 스레드가 맞다. Javascript를 실행하는 스레드는 메인 스레드 1개 밖에 없다. 하지만 일부 Blocking 작업들은 libuv의 스레드 풀에서 수행되기에 완전하게 싱글 스레드라고 보긴 어렵다.

<br />

### 이벤트 기반(Event-driven)

이벤트 기반이란 이벤트가 발생했을 떄 미리 지정해둔 작업을 수행하는 방식을 의미하여, NodeJS는 이벤트 리스너에 등록된 콜백함수를 실행하는 방식으로 동작한다.

```javascript
router.get("/", (req, res, next) => {
  return res.json({ message: "Hello World!" });
});
```

### NodeJS 구성

NodeJS는 Javascript와 C++로 구성되어 있다. V8 엔진도 70% 이상이 C++로 구성되어 있고, libuv는 100% C++로 구성된 라이브러리다. 하지만 V8 엔진에서 Javascript를 C++로 변환해주기에 우리는 저 기능들을 사용할 수 있다.

<br />

<img src="https://github.com/user-attachments/assets/4043cd1e-a82c-4e9b-b989-b8ce7bd21d84" width=400>

<br />

NodeJS는 내장 라이브러리, V8 엔진, libuv로 구성되어있으며, 이벤트 기반, 논블로킹 I/O 모델은 모두 libuv 라이브러리에서 구현된다.

NodeJS에서의 거의 모든 코드는 콜백 함수로 구성되어있으며, 콜백 함수들은 libuv에 위치한 이벤트 루프에서 관리 및 처리된다. 이벤트 루프는 여러 개의 페이즈를 가지고 있고, 페이즈들은 각자만의 큐를 소유한다. 이벤트 루프는 라운드 로빈 방식으로 노드 프로세스가 종료될 때까지 일정 규칙에 따라 여러개의 페이즈들을 계속 순회한다. 페이즈들은 각각의 큐를 관리하고 해당 큐들은 FIFO 순서로 콜백 함수들을 처리한다.

### 논블로킹 I/O(Non-Blocking I/O)

NodeJS에서 논블로킹 I/O 모델은 Input/Output이 관련된 작업들인 Database CRUD, File System 등이 있으며, 블로킹 작업들을 백그라운드에서 수행하고 이를 비동기 콜백 함수로 이벤트 루프에 전달된다.

여기서 백그라운드는 OS의 커널 혹은 libuv의 스레드 풀을 의미한다.

<br />

<img src="https://github.com/user-attachments/assets/7b44620b-2e43-4c50-bc3c-83ca2dd6b5e6" width =400>

<br />

I/O들은 OS 커널 혹은 libuv 내의 스레드 풀에서 담당하는 데 libuv는 어떤 비동기 작업들을 OS 커널에서 지원해주는 지 알고 있기에 작업 종류에 따라 커널에서 처리할 지 스레드 풀에서 처리할 지 분기하고, 작업이 완료되면 이벤트 루프에 이를 알려줘서 콜백 함수로 등록한다. 이 때 libuv의 스레드 풀이 멀티 스레드로 이루어져있다.
