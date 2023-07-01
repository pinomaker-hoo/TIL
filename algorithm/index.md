# MySQL

## 개요

알고리즘을 학습하고 기록 합니다.

<br />

## 목차

- [1. Stack / Queue](#1-stack--queue)
- [2. 시간복잡도, Big-O 표기법](#2-시간복잡도-big-o-표기법)
- [3. Tree](#3-tree)

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

<br />

## 2. 시간복잡도, Big-O 표기법

```
참고 사이트 : https://hanamon.kr/%EC%95%8C%EA%B3%A0%EB%A6%AC%EC%A6%98-time-complexity-%EC%8B%9C%EA%B0%84-%EB%B3%B5%EC%9E%A1%EB%8F%84/
```

<br />

우리가 어떤 문제를 해결하기 위해서 알고리즘의 로직을 코드로 구현할 때 시간 복잡도를 고민한다는 것은 입력 값의 변화에 따라서 연산을 실행할 때 연산횟수에 비해 시간이 얼마나 걸리는가를 의미한다.

효율적인 알고리즘은 입력 값이 커짐에 따라서 증가하는 시간의 비율을 최소하하는 알고리즘을 의미하고 이 시간 복잡도는 빅-오 표기법을 사용한다.

빅오 표기법에는 Big-O(상한 점근), Big-Ω(하한 점근), Big-θ(그 둘의 평균)의 방법이 있고 각각 최악, 최선, 중간의 경우에 대해 나타내지만 최악을 고려하는 빅오 표기법을 가장 많이 사용한다.

<hr />
<br />

### 빅오 표기법의 종류

<br />

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/a68fcd3e-14f1-41d3-b66c-a945d0f36760)

빅오 표기법에는 O(1), O(n), O(log n), O(n2), O(2n)의 종류들이 있다.

1. O(1)

   O(1)은 일정한 복잡도라고 하며 입력 값이 증거한다고 하더라도 시간이 늘어나지 않는 경우를 말한다.

   ```typescript
   const O_1_algorithm(arr : number[], index : number) => {
      return arr[index]
   }

   ```

   이 알고리즘에서는 arr의 사이즈가 아무리 커도 즉시 출력 값을 얻을 수 있다. 따라서 입력 값이 증가하더라도 시간이 늘어나지 않는다.

2. O(n)

   O(n)은 선형 복잡도라고 부르며 입력 값이 증가하면 그 값에 따라 일정하게 시간도 같은 비율로 증가한다.

   입력 값이 10이면 10초가 걸리고 20이면 20초가 걸리는 구조이다.

   ```typescript
   const O_n_algorithm(arr : number[]) => {
     for (const item of arr) [
        console.log("ITEM : " + item)
     ]
   }

   ```

   위의 알고리즘에서는 입력 값이 증가하면 같은 비율로 걸리는 시간이 증가한다.

3. O(log n)

   O(log n)은 로그 복잡도라고 부르며 Big-O 복잡도 중에서 O(1)을 제외하고는 가장 빠른 시간 복잡도를 가진다. 이중 트리에서 사용하는 BST에서는 원하는 값을 탐색 할 때, 노드를 이동할 때 마다 경우의 수가 절반이 줄어들기에 점차 걸리는 시간이 줄어든다.

   O(log n)은 이와 같은 로직이다.

4. O(n2)

   O(n2)는 2차 복잡도라고 부르며 입력 값이 증가할 수록 시간은 n의 제곱의 비율로 증가한다. 즉 3을 넣었더니 3초가 걸렸는데 10을 넣었더니 100초가 걸리는 것이다.

   ```typescript
   const o_quadratic_algorithm(arr : number[]) => {
      for(const item of arr) {
        for (const item2 of arr){
          console.log(item2)
        }
      }
   }
   ```

5. O(2n)

   O(2n)은 기하급수적 복잡도라고 하며 빅오 표기법 중에서 가장 느리다. 종이를 42번 접으면 두께가 달까지 간다는 데 이와 비슷하게 들어간 데이터가 커지면 말도 안되게 시간이 늘어나기에 다른 알고리즘으로 접근하는 것이 좋다.

   ```tpyescript
     const fibonacci = (n) => {
       if( n <= 1){
         return 1
       }
       return fibonacci(n - 1) + fibonacci(n - 2);
     }
   ```

<br />

## 3. TREE

<br />

트리는 0개 이상의 다른 노드에 대한 레퍼런스가 들어있는 노드로 구성되며 단방향 그래프의 한 구조로 ROOT로부터 가지가 사방으로 뻗은 형태라 나무와 닮았다고 하여 TREE라고 부른다.

데이터를 순차적으로 나열시킨 선형 구조가 아닌 하나의 데이터 아래에 여러개의 데이터가 있을 수도 있는 비선형 구조라 싸이클이 없다.

<br />

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/1900b22a-192a-4f28-914e-08e2064b3a8c)

<br />

트리에서 사용하는 언어를 정리해보자.

- Node : 트리 구조를 이루는 모든 개별 데이터
- Root : 트리 구조의 시작점이 되는 Node
- Parent node : 두 노드가 상하관계 일 때 ROOT와 가까운 Node
- Child node : 두 노드가 상하관계 일 때 ROOT와 먼 Node
- depth : 루트로부터의 특정 노드까지의 깊이.
- Level : 같은 깊이를 가지고 있는 Node를 묶어서 표현하며 같은 레벨의 Node는 Sliling Node(형제 노드)라고 한다.
- Leaf : 트리 구조의 끝 지점으로 자식 노드가 없는 노드
- Height : Leaf 노드를 기준으로 Root까지의 높이
- 서브 트리 : 큰 트리 내부에서 트리 구조를 갖춘 작은 트리

<br />

### 이진트리

<br />

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/44aa80f3-5672-415e-a9c2-05be5128e1f3)

보통은 트리는 이진트리를 많이 사용한다고 한다. 이진트리는 트리이지만, 한 노드에 자식이 최대 2개까지 있을 수 있으며, 각각 Left Node, Right Node라고 부른다.

이진트리에서 레벨 i의 최대 노드 갯수는 2^(i - 1)로 레벨 3의 최대 노드 개수는 4이고, 높이가 k인 이진 트리의 최대 노드 개수는 2^(k-1)이다. 레벨이 3이면 최대로 가질 수 있는 노드 개수는 7개다.

트리를 사용하여 데이터를 정렬하고 저장하는 경우를 많이 볼 수 있는 데 가장 흔하게 사용하는 것은 BST, Binary Search Tree다.

이 구조에서는 Left Node는 반드시 부모의 값보다 작고 Right Node는 부모보다 크다.

```

```

```

```
