# MySQL

## 개요

알고리즘을 학습하고 기록 합니다.

<br />

## 목차

- [1. Stack / Queue](#1-stack--queue)

<br />
<br />

## 1. Stack / Queue

<br />

### Stack

Stack이란 후입선출(LIFO)의 구조로 데이터를 쌓아올린 형태의 자료구조를 뜻한다. 데이터를 한 방향으로만 저장 할 수 있고, 최상층으로 정한 곳에 위치한 데이터만 삽입/조회/삭제 할 수 있다.

<br />

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/3d18bc56-5964-4ddd-8b30-d392ac982500)

<br />

프링글스를 생각해보면 위에서부터 과자를 넣어야하지만 가장 먼저 꺼내지는 것은 가장 위에 있는 나중에 들어온 과자인데 이것이 Stack이다.

Stack에는 보통 아래의 기능을 가지게된다.

1. isEmpty() : 스택이 비어있는 지 확인하는 메서드로 boolean을 리턴함.
2. push() : 스택에 새로운 원소를 삽입함.
3. peek() : 최상층의 데이터를 읽는다.
4. pop() : 최상층의 데이터를 읽고 스택에서 제거한다.

이러한 기능을 Typescript로 구현하면 아래와 같다.

```typescript
class Stack<T> {
  private stack: T[];

  constructor() {
    this.stack = [];
    this.limit = 0;
  }

  push(item: T): void {
    this.stack.push(item);
  }

  pop(): T | null {
    if (this.isEmpty()) {
      return null;
    }
    return this.stack.pop()!;
  }

  peek(): T | null {
    if (this.isEmpty()) {
      return null;
    }
    return this.stack[this.stack.length - 1];
  }

  isEmpty(): boolean {
    return this.stack.length === 0;
  }
}
```

<br />

### Queue

<br />

Queue란 선입선출(FIFO)의 구조로 데이터를 순서대로 줄을 세운 형태의 자료구조를 의미하고, Front로 지정한 곳에서는 조회와 삭제가 일어나고 Rear는 삽입 및 연산이 발생한다

<br />

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/8db94332-161b-468a-a48e-90a9b96418f8)

<br />

Queue 보통 아래의 기능을 가지게된다.

1. isEmpty() : 스택이 비어있는 지 확인하는 메서드로 boolean을 리턴함.
2. enqueue() : 큐에 새로운 원소를 삽입한다. 가득 차 있으면 예외를 던진다.
3. peek() : 최하층에 데이터를 읽는다.
4. dequeue() : 최하층에 위치한 데이터를 읽고, 해당 데이터를 큐에서 제거한다.

<br />

### 스택으로 큐, 큐로 스택 구현하기.

<br />

스택은 LIFO이고 스택은 FIFO 구조를 가지고 있지만 스택 2개로 큐를, 큐로 스택을 구현할 수 있다.

먼저 스택 2개를 이용하여 큐를 구현하자. 스택은 먼저 들어오는 데이터가 가장 늦게 들어오는 구조다. 즉 들어오는 순서가 1, 2, 3이라면 나가는 순서는 3, 2, 1이다. 만약 FIFO를 하고 싶다면 큐를 뒤집으면 LIFO에서 FIFO를 구현할 수 있기에 큐를 2개 사용하면 된다.

Stack에 PUSH를 하면 A Stack에 데이터를 쌓고 있다고 POP을 사용하게 되면 A의 모든 데이터를 B로 PUSH 한다면 순서를 뒤집은 스택을 만들 수 있고 B에서도 POP을 준다면 FIFO를 구현할 수 있다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/64dc81d5-4db9-46b1-b828-db84efc10df6)

<br />
<hr />

<br />

큐로 스택을 구현하는 것은 더 간단하다. 데이터를 1, 2, 3을 QUEUE에 넣었고 우리는 스택과 같이 POP 되기를 희망하기에 3, 2, 1이 나와야한다.

그렇다면 QUEUE에 POP을 하지만 처음 들어간 데이터가 나올 때까지는 나온 데이터를 다시 QUEUE에 PUSH를 한다면 스택과 같이 LIFO를 구현할 수 있다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/63a43523-a584-4057-b118-9ca698be52f2)

만약에 STACK과 QUEUE의 특성을 모두 이용하고 싶다면 DEQUE라는 자료구조를 이용할 수도 있따.
