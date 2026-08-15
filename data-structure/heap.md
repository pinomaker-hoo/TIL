# Heap

## 개요

Heap은 "부모가 항상 자식보다 크거나(Max Heap) 작아야(Min Heap) 한다"는 규칙을 지키는 완전 이진 트리다. 이 규칙 덕분에 최댓값 또는 최솟값을 항상 Root에서 O(1)로 읽을 수 있고, 삽입/삭제도 O(log n)에 처리된다.

"전체 정렬은 필요 없고, 매번 가장 크거나 작은 것 하나만 빨리 꺼내면 되는" 상황을 위한 자료구조이며, Priority Queue(우선순위 큐)의 표준 구현체다.

```
V8의 setTimeout 타이머 관리, OS의 프로세스 스케줄링, 다익스트라 최단 경로,
BullMQ의 우선순위 작업 처리 모두 Heap 기반이다.
"매번 정렬하면 되지 않나?"라는 생각이 들 때, 삽입마다 정렬하면 O(n log n)이지만
Heap은 O(log n)으로 같은 일을 한다.
```

<br /> <br />

## Heap의 구조

Heap은 두 가지 조건을 만족한다.

1. 완전 이진 트리 : 마지막 레벨을 제외하고 꽉 차 있고, 마지막 레벨은 왼쪽부터 채워진다.
2. Heap 속성 : Max Heap이면 부모 ≥ 자식, Min Heap이면 부모 ≤ 자식. (형제끼리의 대소 관계는 상관없다)

```
=====================================================
[시각화] Min Heap
=====================================================

                 [ 1 ]          <-- 항상 최솟값이 Root
                /     \
            [ 3 ]     [ 2 ]     <-- 형제(3, 2)끼리는 순서가 없어도 됨
            /   \
        [ 7 ]  [ 5 ]

* BST와 달리 "부모-자식 간의 대소"만 보장한다. 전체가 정렬된 것이 아니다.
```

<br />

## 배열로 표현하기

완전 이진 트리는 빈 칸 없이 왼쪽부터 채워지기 때문에 포인터 없이 배열만으로 표현할 수 있다. Index 계산만으로 부모/자식을 오갈 수 있다.

- 부모 index : `Math.floor((i - 1) / 2)`
- 왼쪽 자식 index : `2i + 1`
- 오른쪽 자식 index : `2i + 2`

```
=====================================================
[시각화] Heap의 배열 표현
=====================================================

 트리 :        [ 1 ]
              /     \
          [ 3 ]     [ 2 ]
          /   \
      [ 7 ]  [ 5 ]

 배열 :  index  0    1    2    3    4
        value [ 1 ][ 3 ][ 2 ][ 7 ][ 5 ]

* index 1(값 3)의 자식은 index 3(값 7)과 index 4(값 5)
* 포인터가 필요 없어 메모리 효율이 좋고 캐시 친화적이다.
```

<br />

## 핵심 연산

### 삽입 (Bubble Up) : O(log n)

배열의 맨 끝(트리의 마지막 자리)에 넣은 뒤, 부모보다 작으면(Min Heap 기준) 부모와 교환하며 위로 올라간다.

```
=====================================================
[시각화] Min Heap에 0 삽입
=====================================================

 1) 맨 끝에 추가          2) 부모 3과 비교, 교환      3) 부모 1과 비교, 교환
       [ 1 ]                    [ 1 ]                    [ 0 ]
      /     \                  /     \                  /     \
   [ 3 ]   [ 2 ]            [ 0 ]   [ 2 ]            [ 1 ]   [ 2 ]
   /   \                    /   \                    /   \
[ 7 ] [ 0 ]              [ 7 ] [ 3 ]              [ 7 ] [ 3 ]

* 트리 높이(log n)만큼만 올라가면 끝난다.
```

### 최솟값 삭제 (Bubble Down) : O(log n)

Root를 꺼낸 뒤, 배열의 맨 끝 요소를 Root 자리로 옮기고 자식 중 더 작은 쪽과 교환하며 아래로 내려간다.

<br />

## Typescript로 Min Heap 구현하기

```typescript
class MinHeap {
  private heap: number[] = [];

  peek(): number | null {
    return this.heap[0] ?? null;
  }

  size(): number {
    return this.heap.length;
  }

  push(value: number): void {
    this.heap.push(value);
    this.bubbleUp(this.heap.length - 1);
  }

  pop(): number | null {
    if (this.heap.length === 0) return null;

    const min = this.heap[0];
    const last = this.heap.pop()!;

    if (this.heap.length > 0) {
      this.heap[0] = last;
      this.bubbleDown(0);
    }
    return min;
  }

  private bubbleUp(index: number): void {
    while (index > 0) {
      const parent = Math.floor((index - 1) / 2);
      if (this.heap[index] >= this.heap[parent]) break;

      [this.heap[index], this.heap[parent]] = [this.heap[parent], this.heap[index]];
      index = parent;
    }
  }

  private bubbleDown(index: number): void {
    const length = this.heap.length;

    while (true) {
      const left = 2 * index + 1;
      const right = 2 * index + 2;
      let smallest = index;

      if (left < length && this.heap[left] < this.heap[smallest]) smallest = left;
      if (right < length && this.heap[right] < this.heap[smallest]) smallest = right;
      if (smallest === index) break;

      [this.heap[index], this.heap[smallest]] = [this.heap[smallest], this.heap[index]];
      index = smallest;
    }
  }
}

const heap = new MinHeap();
[5, 3, 8, 1, 9].forEach((n) => heap.push(n));

console.log(heap.pop()); // 1
console.log(heap.pop()); // 3
console.log(heap.peek()); // 5
```

<br />

## Priority Queue

Priority Queue는 "들어온 순서가 아니라 우선순위 순서로 나가는 Queue"라는 추상 개념(ADT)이고, Heap은 그것을 구현하는 가장 효율적인 자료구조다. 위 구현에서 number 대신 `{ priority, value }` 객체를 넣고 priority로 비교하면 그대로 Priority Queue가 된다.

| 구현 방식        | 삽입     | 최우선 꺼내기 |
| ---------------- | -------- | ------------- |
| 정렬 안 된 배열  | O(1)     | O(n)          |
| 정렬된 배열      | O(n)     | O(1)          |
| Heap             | O(log n) | O(log n)      |

삽입과 꺼내기가 섞여서 반복되는 실제 시나리오에서는 양쪽 모두 O(log n)인 Heap이 압도적으로 유리하다.

```
JavaScript에는 아직 표준 Priority Queue가 없어서 직접 구현하거나 heap-js 같은 라이브러리를 쓴다.
코딩 테스트에서 "가장 작은/큰 것을 반복해서 꺼내는" 문제(K번째 수, 작업 스케줄링, 다익스트라)가
나오면 Heap을 떠올리면 된다.
```

<br />

## Heap Sort와 활용

1. Heap Sort : 모든 데이터를 Heap에 넣고 하나씩 pop하면 정렬된다. O(n log n)이며 추가 메모리가 필요 없지만, 캐시 지역성이 나빠 실무 정렬은 보통 Quick/Tim Sort를 쓴다.
2. Top-K 문제 : "1억 개 중 가장 큰 10개"를 찾을 때 전체 정렬(O(n log n)) 대신 크기 10짜리 Min Heap을 유지하면 O(n log 10)으로 해결된다. 대용량 로그에서 상위 N개 추출이 이 패턴이다.
3. 다익스트라 알고리즘 : "아직 방문 안 한 노드 중 가장 가까운 노드"를 반복해서 꺼내야 하므로 Min Heap이 핵심 부품이다.
4. 타이머/스케줄러 : "가장 먼저 만료되는 타이머"를 빨리 찾아야 하는 libuv의 타이머 관리가 Min Heap이다.

<br />

## 정리

1. Heap은 부모-자식 간 대소 관계만 보장하는 완전 이진 트리로, 최댓값/최솟값 조회 O(1), 삽입/삭제 O(log n)이다.
2. 완전 이진 트리라서 포인터 없이 배열과 Index 계산만으로 구현할 수 있다.
3. Priority Queue의 표준 구현체이며, "가장 크거나 작은 것을 반복해서 꺼내는" 모든 문제(Top-K, 다익스트라, 스케줄링)의 답이다.
4. 전체 정렬이 필요 없다면 정렬(O(n log n)) 대신 Heap(O(log n) 삽입)을 쓰는 것이 효율적이다.
