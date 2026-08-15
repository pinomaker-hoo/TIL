# Linked List

## 개요

Linked List는 데이터를 담은 Node들이 포인터(참조)로 연결되어 있는 선형 자료구조다. 배열처럼 데이터가 메모리에 연속으로 붙어있는 것이 아니라, 각 Node가 "다음 Node가 어디에 있는지"를 가리키는 참조를 들고 흩어져 있는 구조다.

배열은 크기가 고정되어 있고 중간 삽입/삭제 시 뒤의 요소를 전부 밀어야 하지만, Linked List는 포인터만 바꾸면 되기 때문에 삽입/삭제가 O(1)이다. 대신 특정 위치에 접근하려면 처음부터 순회해야 해서 조회는 O(n)이다.

```
Node 기반 연결 구조는 Linked List 자체로 쓰이기보다 다른 자료구조의 부품으로 더 많이 쓰인다.
Hash Table의 Separate Chaining, Queue/Deque의 내부 구현, LRU 캐시 등이 대표적이다.
```

<br /> <br />

## Linked List의 구조

Linked List는 2가지 요소로 구성된다.

1. Node : 실제 데이터(value)와 다음 Node를 가리키는 참조(next)를 가진 단위
2. Head : 리스트의 시작 Node를 가리키는 참조 (끝을 가리키는 Tail을 함께 유지하기도 한다)

```
=====================================================
[시각화] Singly Linked List
=====================================================

 Head
  |
  v
[ A | next ] --> [ B | next ] --> [ C | next ] --> null

* 각 Node는 자신의 데이터와 "다음 Node의 주소"만 알고 있다.
* 마지막 Node의 next는 null로, 리스트의 끝을 의미한다.
```

<br />

## Linked List의 종류

1. Singly Linked List (단일 연결 리스트) : 각 Node가 next 참조 하나만 가진다. 한 방향으로만 순회할 수 있다.
2. Doubly Linked List (이중 연결 리스트) : next와 prev를 모두 가져 양방향 순회가 가능하다. 특정 Node를 알고 있을 때 그 Node를 O(1)로 삭제할 수 있다는 것이 큰 장점이다.
3. Circular Linked List (원형 연결 리스트) : 마지막 Node의 next가 다시 Head를 가리킨다. 라운드 로빈 스케줄링처럼 순환이 필요한 곳에 쓰인다.

```
=====================================================
[시각화] Doubly Linked List
=====================================================

 Head                                        Tail
  |                                           |
  v                                           v
null <-- [ prev | A | next ] <--> [ prev | B | next ] <--> [ prev | C | next ] --> null

* prev가 있기 때문에 뒤에서 앞으로도 순회할 수 있고,
  중간 Node 삭제 시 앞 Node를 찾기 위해 처음부터 순회할 필요가 없다.
```

<br />

## 배열 vs Linked List

| 연산                  | 배열 | Linked List |
| --------------------- | ---- | ----------- |
| Index 접근            | O(1) | O(n)        |
| 맨 앞 삽입/삭제       | O(n) | O(1)        |
| 맨 뒤 삽입 (Tail 유지) | O(1) | O(1)        |
| 중간 삽입/삭제        | O(n) | O(1)*       |
| 탐색                  | O(n) | O(n)        |

\* 중간 삽입/삭제 자체는 O(1)이지만, 그 위치까지 찾아가는 데 O(n)이 걸린다. "해당 Node의 참조를 이미 들고 있는 경우"에만 진짜 O(1)이다.

```
이론적으로는 삽입/삭제가 잦으면 Linked List가 유리하다고 배우지만, 현대 CPU에서는
배열이 메모리에 연속으로 배치되어 캐시 적중률이 압도적으로 높기 때문에
작은 규모에서는 배열이 Linked List보다 빠른 경우가 많다.
Linked List가 진짜 힘을 발휘하는 곳은 "Node 참조를 직접 들고 있는" LRU 캐시 같은 패턴이다.
```

<br />

## Typescript로 Linked List 구현하기

Singly Linked List를 구현하면 아래와 같다.

```typescript
class ListNode<T> {
  value: T;
  next: ListNode<T> | null = null;

  constructor(value: T) {
    this.value = value;
  }
}

class LinkedList<T> {
  private head: ListNode<T> | null = null;
  private tail: ListNode<T> | null = null;
  private length = 0;

  // 맨 뒤 삽입 : Tail을 유지하기 때문에 O(1)
  append(value: T): void {
    const node = new ListNode(value);

    if (!this.tail) {
      this.head = node;
      this.tail = node;
    } else {
      this.tail.next = node;
      this.tail = node;
    }
    this.length++;
  }

  // 맨 앞 삽입 : O(1)
  prepend(value: T): void {
    const node = new ListNode(value);
    node.next = this.head;
    this.head = node;

    if (!this.tail) {
      this.tail = node;
    }
    this.length++;
  }

  // 탐색 : O(n)
  find(value: T): ListNode<T> | null {
    let current = this.head;
    while (current) {
      if (current.value === value) {
        return current;
      }
      current = current.next;
    }
    return null;
  }

  // 삭제 : 앞 Node의 next를 삭제 대상의 next로 바꿔치기, O(n)
  delete(value: T): boolean {
    if (!this.head) return false;

    if (this.head.value === value) {
      this.head = this.head.next;
      if (!this.head) this.tail = null;
      this.length--;
      return true;
    }

    let current = this.head;
    while (current.next) {
      if (current.next.value === value) {
        if (current.next === this.tail) {
          this.tail = current;
        }
        current.next = current.next.next;
        this.length--;
        return true;
      }
      current = current.next;
    }
    return false;
  }

  toArray(): T[] {
    const result: T[] = [];
    let current = this.head;
    while (current) {
      result.push(current.value);
      current = current.next;
    }
    return result;
  }
}

const list = new LinkedList<number>();
list.append(1);
list.append(2);
list.prepend(0);
console.log(list.toArray()); // [0, 1, 2]
list.delete(1);
console.log(list.toArray()); // [0, 2]
```

<br />

## 활용 예시 : LRU 캐시

Linked List의 대표적인 실무 활용은 LRU(Least Recently Used) 캐시다. "가장 오래 사용되지 않은 데이터를 버리는" 캐시를 만들려면 아래 두 연산이 모두 빨라야 한다.

1. Key로 데이터를 O(1)에 찾기 --> Hash Table
2. 사용 순서를 갱신하고 가장 오래된 것을 O(1)에 제거하기 --> Doubly Linked List

Hash Table의 Value로 Doubly Linked List의 Node 참조를 저장하면, 조회 시 해당 Node를 리스트 맨 앞으로 옮기고(최근 사용), 캐시가 가득 차면 리스트 맨 뒤 Node(가장 오래됨)를 제거하는 방식으로 모든 연산이 O(1)이 된다. Redis의 LRU eviction도 이와 같은 원리다.

```
=====================================================
[시각화] LRU 캐시 = Hash Table + Doubly Linked List
=====================================================

 Hash Table                Doubly Linked List (사용 순서)
 -------------
 | "a" | ●---|---------->  [ a ] <--> [ c ] <--> [ b ]
 | "b" | ●---|----------------------------------^
 | "c" | ●---|----------------------^
 -------------             ^ 최근 사용            ^ 가장 오래됨 (다음 제거 대상)
```

<br />

## 정리

1. Linked List는 Node들이 참조로 연결된 선형 자료구조로, 삽입/삭제는 O(1)이지만 접근/탐색은 O(n)이다.
2. Singly / Doubly / Circular 3가지 형태가 있으며, Doubly는 Node 참조만 있으면 O(1) 삭제가 가능하다.
3. 현대 CPU에서는 캐시 지역성 때문에 단순 순회/조회는 배열이 더 빠른 경우가 많다.
4. Hash Table과 조합한 LRU 캐시처럼, 다른 자료구조의 부품으로 쓰일 때 진가를 발휘한다.
