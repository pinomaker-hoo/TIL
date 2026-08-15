# Stack & Queue

## 개요

Stack과 Queue는 "데이터를 넣고 빼는 순서"에 제약을 둔 선형 자료구조다.

- Stack : 후입선출(LIFO, Last In First Out). 나중에 넣은 것이 먼저 나온다.
- Queue : 선입선출(FIFO, First In First Out). 먼저 넣은 것이 먼저 나온다.

단순해 보이지만 함수 호출(Call Stack), 이벤트 루프의 Task Queue, 메시지 큐(BullMQ, SQS), 브라우저 히스토리, Ctrl+Z(undo)까지 시스템의 뼈대 곳곳에서 쓰이는 가장 기본적인 자료구조다.

<br /> <br />

## Stack

Stack은 한쪽 끝(top)에서만 삽입과 삭제가 일어나는 구조다. 프링글스 통처럼 마지막에 넣은 과자를 가장 먼저 꺼내게 된다.

```
=====================================================
[시각화] Stack (LIFO)
=====================================================

 push(C) -->  | C |  --> pop()  : C가 먼저 나옴
              | B |
              | A |
              -----
              top이 위, 삽입과 삭제 모두 위에서만 일어난다.
```

주요 연산은 아래와 같고, 모두 O(1)이다.

1. push(item) : top에 데이터를 쌓는다.
2. pop() : top의 데이터를 꺼내고 제거한다.
3. peek() : top의 데이터를 제거하지 않고 읽는다.
4. isEmpty() : 비어있는지 확인한다.

```typescript
class Stack<T> {
  private items: T[] = [];

  push(item: T): void {
    this.items.push(item);
  }

  pop(): T | null {
    return this.items.pop() ?? null;
  }

  peek(): T | null {
    return this.items[this.items.length - 1] ?? null;
  }

  isEmpty(): boolean {
    return this.items.length === 0;
  }
}
```

<br />

### Stack이 쓰이는 곳

1. Call Stack : 함수가 호출되면 push, return되면 pop된다. 재귀가 탈출 조건 없이 돌면 `Maximum call stack size exceeded`가 나는 이유다.
2. 괄호 검사 / 수식 파싱 : 여는 괄호를 push하고 닫는 괄호를 만나면 pop하여 짝을 검증한다. 컴파일러와 JSON 파서가 이 원리로 동작한다.
3. Undo/Redo : 작업 이력을 Stack에 쌓고 Ctrl+Z 시 pop한다.
4. DFS(깊이 우선 탐색) : 재귀 대신 명시적 Stack으로 구현할 수 있다.

```typescript
// 대표 문제 : 유효한 괄호 검사
const isValidParentheses = (str: string): boolean => {
  const stack: string[] = [];
  const pairs: Record<string, string> = { ")": "(", "]": "[", "}": "{" };

  for (const char of str) {
    if (char === "(" || char === "[" || char === "{") {
      stack.push(char);
    } else if (pairs[char]) {
      if (stack.pop() !== pairs[char]) {
        return false;
      }
    }
  }
  return stack.length === 0;
};

console.log(isValidParentheses("({[]})")); // true
console.log(isValidParentheses("({[})"));  // false
```

<br />

## Queue

Queue는 뒤(rear)에서 삽입하고 앞(front)에서 삭제하는 구조다. 은행 대기줄처럼 먼저 온 사람이 먼저 처리된다.

```
=====================================================
[시각화] Queue (FIFO)
=====================================================

 enqueue(D)                            dequeue()
    |                                     |
    v                                     v
  rear [ D | C | B | A ] front  -->  A가 먼저 나옴

 * 삽입은 rear에서만, 삭제는 front에서만 일어난다.
```

주요 연산은 아래와 같다.

1. enqueue(item) : rear에 데이터를 삽입한다.
2. dequeue() : front의 데이터를 꺼내고 제거한다.
3. peek() : front의 데이터를 제거하지 않고 읽는다.

```
JavaScript에서 배열의 shift()로 dequeue를 구현하면 앞의 요소를 제거할 때마다
나머지 전체가 한 칸씩 당겨지기 때문에 O(n)이 걸린다.
소량 데이터면 상관없지만, 대량 데이터를 다루는 Queue라면
Linked List 기반 구현이나 아래처럼 front 포인터를 이동시키는 방식을 써야 한다.
```

```typescript
class Queue<T> {
  private items: T[] = [];
  private front = 0;

  enqueue(item: T): void {
    this.items.push(item);
  }

  // shift() 대신 front 포인터만 이동시켜 O(1)을 보장한다
  dequeue(): T | null {
    if (this.isEmpty()) return null;

    const item = this.items[this.front];
    this.front++;

    // 앞쪽에 버려진 공간이 절반을 넘으면 정리
    if (this.front * 2 > this.items.length) {
      this.items = this.items.slice(this.front);
      this.front = 0;
    }
    return item;
  }

  peek(): T | null {
    return this.isEmpty() ? null : this.items[this.front];
  }

  isEmpty(): boolean {
    return this.front >= this.items.length;
  }
}
```

<br />

### Queue의 변형

1. Circular Queue (원형 큐) : 고정 크기 배열의 끝과 처음을 이어붙여 공간을 재활용한다. 커널 버퍼, 스트리밍 버퍼에 쓰인다.
2. Deque (Double-Ended Queue) : 양쪽 끝 모두에서 삽입/삭제가 가능하다. Stack과 Queue를 하나로 커버한다.
3. Priority Queue (우선순위 큐) : 들어온 순서가 아니라 우선순위가 높은 것이 먼저 나온다. 보통 Heap으로 구현한다. ([heap.md](./heap.md) 참고)

<br />

### Queue가 쓰이는 곳

1. 이벤트 루프 : NodeJS의 Task Queue(Macrotask/Microtask)가 Queue 구조다. Call Stack이 비면 Queue에서 콜백을 꺼내 실행한다.
2. 메시지 큐 : BullMQ, RabbitMQ, SQS 같은 작업 큐는 "먼저 등록된 작업을 먼저 처리한다"는 Queue의 개념을 시스템 레벨로 확장한 것이다.
3. BFS(너비 우선 탐색) : 가까운 노드부터 순서대로 방문하기 위해 Queue를 사용한다.
4. 버퍼링 : 생산 속도와 소비 속도가 다른 두 시스템 사이에서 완충 역할을 한다.

```
API 서버에서 이메일 발송, 이미지 처리처럼 오래 걸리는 작업을 요청 처리 중에 직접 수행하지 않고
Queue에 넣고 즉시 응답한 뒤 Worker가 꺼내 처리하는 패턴이 실무에서 가장 많이 쓰는 Queue 활용이다.
```

<br />

## Stack 2개로 Queue 구현하기

면접 단골 문제다. Stack은 넣은 순서를 뒤집어서 내보내는데, 두 번 뒤집으면 원래 순서가 되는 성질을 이용한다.

- enqueue : inStack에 push
- dequeue : outStack이 비어있으면 inStack의 모든 데이터를 pop해서 outStack에 push한 뒤, outStack에서 pop

```
=====================================================
[시각화] Stack 2개로 Queue 만들기
=====================================================

 1, 2, 3 순서로 enqueue        dequeue 시 옮겨 담기

 inStack        outStack       inStack        outStack
 | 3 |          |   |          |   |          | 1 |  <-- pop하면 1
 | 2 |   --->   |   |          |   |          | 2 |      (FIFO 완성)
 | 1 |          |   |          |   |          | 3 |
 -----          -----          -----          -----
```

옮겨 담는 작업은 outStack이 비었을 때만 일어나므로, 각 원소는 평생 최대 2번만 이동한다. 따라서 분할 상환 관점에서 dequeue도 O(1)이다.

```typescript
class QueueWithStacks<T> {
  private inStack: T[] = [];
  private outStack: T[] = [];

  enqueue(item: T): void {
    this.inStack.push(item);
  }

  dequeue(): T | null {
    if (this.outStack.length === 0) {
      while (this.inStack.length > 0) {
        this.outStack.push(this.inStack.pop()!);
      }
    }
    return this.outStack.pop() ?? null;
  }
}
```

<br />

## 정리

1. Stack은 LIFO 구조로 Call Stack, 괄호 검사, Undo, DFS에 쓰인다.
2. Queue는 FIFO 구조로 이벤트 루프, 메시지 큐, BFS, 버퍼링에 쓰인다.
3. JavaScript에서 배열 shift()는 O(n)이므로 대량 데이터 Queue는 포인터 이동이나 Linked List로 구현해야 한다.
4. Stack 2개로 Queue를, Queue로 Stack을 만들 수 있으며 양쪽 특성이 모두 필요하면 Deque를 쓴다.
