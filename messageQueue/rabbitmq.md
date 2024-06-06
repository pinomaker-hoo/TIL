# RabbitMQ

<img src='https://github.com/pinomaker-hoo/TIL/assets/56928532/51680bd0-c073-478e-a933-67a51d07f6ce' width='300px'/>

<br />

RabbitMQ는 AMQP(Advanced Message Queuing Protocol)를 구현한 오픈소스 메세지 브로커다.

RabbitMQ에서 중요한 개념으로는 Producer, Comsumer, Queue, Exchange, Binding이 있다.

### Producer

Producer는 메세지를 생성하고 발송하는 주체를 의미한다. 이 메세지는 Queue에 저장이 되게 되고 이 메세지를 Comsumer가 컨슘하여 사용하게 된다.

쉽게 생각해서 이벤트를 발행하는 자라고 생각하면 된다.

### Consumer

Producer가 생성하는 주체라면 Consumer는 그 메세지를 수신하는 주체를 의미한다. Consumer는 Queue에 직접 접근하여 메세지를 가져오게 되며, 보통은 Producer가 등록한 메세지를 Comsume하여 특정 로직을 처리하는 데 사용한다.

### Queue

Producer가 발송한 메세지들이 Consumer가 소비하기 전에 보관되는 장소로, Queue는 이름으로 구분하게 된다. 같은 이름 + 같은 설정을 Queue를 생성하면 문제가 없지만 같은 이름 + 다른 설정으로 생성하면 에러가 발생한다.

### Binding

Binding은 Exchange에게 메세지를 라우팅할 규칙을 지정하는 행위다. 특정 조건에 맞는 메세지를 특정 큐에 전송하도록 설정할 수 있는 데 Exchange 타입에 맞게 설정해야한다.

### Exchange

Producer가 발행한 메세지를 Queue에 저장할 때 직접 접근하는 것이 아닌 Exchange를 통하여 접근하게 된다. Exchange는 Producer로부터 전달 받은 메세지를 어떤 Queue에 전달할 지 결정하는 객체인데 라우터라고 생각하면 편하다. Exchange는 Direct, Topic, Headers, Fanout으로 4가지의 종류가 있다.

(1) Direct Exchange

Direct Exchange는 라우팅 키를 이용하여 메세지를 라우팅하는 데, 하나의 큐에 여러 개의 라우팅 키를 지정하는 것도 가능하다. 참고로 RabitMQ의 기본 Exchange는 Direct Exchange다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/a578278b-b590-472e-9725-30bd9d377888)

출처 : [https://www.google.com/url?sa=i&url=https%3A%2F%2Fjstobigdata.com%2Frabbitmq%2Fdirect-exchange-in-amqp-rabbitmq%2F&psig=AOvVaw1QJUNCHlHrYhZutSJVVeRa&ust=1717771274562000&source=images&cd=vfe&opi=89978449&ved=0CBQQjhxqFwoTCPj5vOiax4YDFQAAAAAdAAAAABAE]

<br />

(2) Topic Exchange

Toic Exchange는 라우팅 키 패턴을 이용하여 메세지를 전달한다. 키 이름에 대해 접근하는 게 아니라 패턴에 의해 접근하게 되며 1개의 메세지를 여러개의 큐에도 전달이 가능하다.

```
A Queue : *.sample.*

B Queue : *.*.sample

2개의 Queue가 있다고 가정할 때 a.sample.sample로 지정하여 Message를 발급하면 A, B 2개의 큐에 데이터를 저장한다.
```

<br />

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/dec2f61a-3566-4971-921a-e00bdf16b54a)

출처 : [https://www.google.com/url?sa=i&url=https%3A%2F%2Fjstobigdata.com%2Frabbitmq%2Ftopic-exchange-in-amqp-rabbitmq%2F&psig=AOvVaw1GgqjadfVnQoob7sXtA07g&ust=1717771392477000&source=images&cd=vfe&opi=89978449&ved=0CBQQjhxqFwoTCKi6pJ-bx4YDFQAAAAAdAAAAABAE]

<br />

(3) Headers Exchange

Topic Exchange와 유사하지만 라우팅을 위하여 Header를 구성하여 이를 이용해 메세지를 전달한다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/a506e784-5cfc-498a-92ac-30b3aad14cfe)

출처 : [https://www.google.com/url?sa=i&url=https%3A%2F%2Fjstobigdata.com%2Frabbitmq%2Fheaders-exchange-in-amqp-rabbitmq%2F&psig=AOvVaw0W6aAdjkfAE0oIjT6ytGJC&ust=1717771556501000&source=images&cd=vfe&opi=89978449&ved=0CBQQjhxqFwoTCMCW6uybx4YDFQAAAAAdAAAAABAE]

<br />

(4) Fanout Exchange

Fanout Exchange는 exchange에 등록된 모든 Queue에 메세지를 전달한다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/b9f036be-9a45-4d49-ad0f-39bac09ba28b)

출처 : [https://www.google.com/url?sa=i&url=https%3A%2F%2Fjstobigdata.com%2Frabbitmq%2Ffanout-exchange-in-amqp-rabbitmq%2F&psig=AOvVaw3UmViy1EGgAgMkeSlWb04o&ust=1717771624278000&source=images&cd=vfe&opi=89978449&ved=0CBQQjhxqFwoTCKj3k42cx4YDFQAAAAAdAAAAABAE]

## RabbitMQ 특징

- RabbitMQ는 RabbitMQ 서버가 종료 후 재가동하면 기본적으론 Queue가 모두 제거된다. 이를 방지하기 위해 Queue를 생성할 때 Durable 옵션을 줄 수 있으며, Producer도 메세지를 발행할 때 PERSISTENT_TEXT_PLAIN 옵션을 주어야한다.

- 큐가 비어있다면 성능이 빠르며 1초에 수백만개의 메세지를 처리가 가능하지만 자원을 더 필요로 한다.

- Message의 Consumer가 1개라면 메세지 순서를 보장하지만 여러 Consumer가 존재하면 처리 순서를 보장할 수 없다.

- Exchange를 통하여 다양하게 라우팅을 할 수 있다.

- Consumer가 메세지를 소비하면 ACK 메세지를 보내고 메세지를 삭제하며, NACK가 수신되면 다시 큐에 보내진다.
