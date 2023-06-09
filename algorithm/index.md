# MySQL

## 개요

알고리즘을 학습하고 기록 합니다.

<br />

## 목차

- [1. Stack / Queue](#1-stack--queue)

<br />
<br />

## 1. Stack / Queue

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
