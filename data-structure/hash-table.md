# Hash Table

## 개요

Hash Table은 Key를 Hash Function에 넣어 나온 Hash 값을 배열의 Index로 사용하여 데이터를 저장하는 자료구조다. Key만 알면 배열의 몇 번째 칸을 봐야 하는지 즉시 계산할 수 있기 때문에 삽입/조회/삭제를 평균 O(1)에 처리할 수 있다.

JavaScript의 Object와 Map, Python의 Dictionary, Java의 HashMap이 모두 Hash Table을 기반으로 구현되어 있고, Redis 같은 Key-Value 저장소나 DB 인덱스의 Hash Index도 같은 원리로 동작한다.

```
실무에서 "이 데이터를 어떻게 빨리 찾지?"라는 문제의 대부분은 결국 Hash Table로 해결된다.
중복 체크, 캐싱, 카운팅, 그룹핑 모두 Hash Table의 O(1) 조회를 이용하는 패턴이다.
```

<br /> <br />

## Hash Table의 구조

Hash Table은 크게 3가지 요소로 구성된다.

1. Key : 저장할 데이터를 식별하는 값 (예: "apple")
2. Hash Function : Key를 받아서 배열의 Index로 변환하는 함수
3. Bucket : 실제 데이터가 저장되는 배열의 각 칸

```
=====================================================
[시각화] Hash Table의 기본 동작
=====================================================

  Key        Hash Function        Bucket (배열)
                                 -----------------
"apple"  --->  hash("apple")     | 0 |           |
               = 2               | 1 |           |
                            ---> | 2 | "apple"   |
"banana" --->  hash("banana")    | 3 |           |
               = 5               | 4 |           |
                            ---> | 5 | "banana"  |
                                 -----------------

* 배열 전체를 탐색할 필요 없이 hash(key)만 계산하면 바로 위치를 알 수 있다.
```

배열에서 값을 찾으려면 처음부터 끝까지 순회해야 해서 O(n)이 걸리지만, Hash Table은 Hash Function의 계산 결과가 곧 위치이기 때문에 O(1)이 된다.

<br />

## Hash Function

Hash Function은 임의의 Key를 받아서 고정된 범위(배열 크기)의 정수로 변환하는 함수다. 좋은 Hash Function은 아래 조건을 만족해야 한다.

1. 결정적(Deterministic) : 같은 Key를 넣으면 항상 같은 값이 나와야 한다.
2. 균등 분포(Uniform Distribution) : 특정 Bucket에 데이터가 몰리지 않고 고르게 퍼져야 한다.
3. 빠른 계산 : Hash 계산 자체가 느리면 O(1)의 의미가 없다.

문자열 Key를 해싱하는 가장 단순한 방법은 각 문자의 문자 코드를 더한 뒤 배열 크기로 나눈 나머지를 사용하는 것이다.

```typescript
const simpleHash = (key: string, bucketSize: number): number => {
  let hash = 0;
  for (const char of key) {
    hash += char.charCodeAt(0);
  }
  return hash % bucketSize;
};
```

하지만 이 방식은 "abc"와 "cba"처럼 같은 문자로 구성된 Key가 항상 같은 Index로 계산되는 문제가 있다. 그래서 실제로는 문자의 순서까지 반영하기 위해 소수(prime number)를 곱해가며 누적하는 방식을 많이 사용한다. (Java의 String.hashCode()가 31을 곱하는 방식이 대표적이다.)

```typescript
const hash = (key: string, bucketSize: number): number => {
  let hash = 0;
  for (const char of key) {
    hash = (hash * 31 + char.charCodeAt(0)) % bucketSize;
  }
  return hash;
};
```

<br />

## Hash Collision (해시 충돌)

Bucket의 개수는 유한한데 Key의 종류는 무한하기 때문에, 서로 다른 Key가 같은 Index로 계산되는 상황이 반드시 발생한다. 이를 Hash Collision이라고 하며, Hash Table 구현의 핵심은 이 충돌을 어떻게 처리하느냐에 있다.

```
=====================================================
[시각화] 해시 충돌
=====================================================

"cat"  --->  hash("cat") = 3  ----
                                  \      -----------------
                                   ---> | 3 | ??? |
                                  /      -----------------
"dog"  --->  hash("dog") = 3  ----

* 서로 다른 Key인데 같은 칸을 가리킨다. 이대로 저장하면 기존 데이터를 덮어쓰게 된다.
```

충돌 해결 방법은 크게 2가지가 있다.

<br />

### 1. Separate Chaining (분리 연결법)

각 Bucket에 값을 하나만 저장하는 게 아니라, Linked List(또는 배열)로 여러 개를 연결해서 저장하는 방식이다. 충돌이 나면 같은 Bucket의 리스트 뒤에 이어 붙인다.

```
=====================================================
[시각화] Separate Chaining
=====================================================

-----------------
| 0 |           |
| 1 |           |
| 2 |           |
| 3 | ["cat", 1] -> ["dog", 2]     <-- 충돌난 데이터를 리스트로 연결
| 4 |           |
-----------------

* 조회 시에는 hash(key)로 Bucket을 찾은 뒤, 리스트를 순회하며 Key가 일치하는 것을 찾는다.
```

구현이 간단하고 데이터가 많아져도 동작한다는 장점이 있지만, 한 Bucket에 데이터가 몰리면 리스트 순회 때문에 최악의 경우 O(n)까지 느려진다.

```
Java의 HashMap은 Separate Chaining을 사용하는데, 하나의 Bucket에 데이터가 8개 이상 쌓이면
Linked List를 Red-Black Tree로 변환하여 최악의 경우에도 O(log n)을 보장하도록 최적화되어 있다.
```

<br />

### 2. Open Addressing (개방 주소법)

충돌이 나면 다른 비어있는 Bucket을 찾아서 저장하는 방식이다. 빈 칸을 찾는 방법에 따라 3가지로 나뉜다.

1. Linear Probing (선형 탐사) : 충돌 시 바로 다음 칸(+1, +2, +3...)을 순서대로 확인한다. 구현이 쉽지만 데이터가 연속된 구간에 뭉치는 클러스터링(Clustering) 문제가 발생한다.
2. Quadratic Probing (제곱 탐사) : +1, +4, +9... 처럼 제곱수만큼 건너뛰며 확인하여 클러스터링을 완화한다.
3. Double Hashing (이중 해싱) : 두 번째 Hash Function으로 이동 간격을 계산하여 Key마다 다른 간격으로 탐사한다.

```
=====================================================
[시각화] Linear Probing
=====================================================

"dog"의 hash가 3인데 이미 "cat"이 있는 상황

-----------------
| 2 |           |
| 3 | "cat"     |  <-- 이미 차 있음, 다음 칸 확인
| 4 | "dog"     |  <-- 비어 있으니 여기에 저장
| 5 |           |
-----------------

* 조회 시에도 같은 순서로 탐사하며 Key가 일치할 때까지 확인한다.
```

Open Addressing은 별도의 리스트가 필요 없어 메모리 효율이 좋고 캐시 친화적이지만, 데이터가 많이 차면 빈 칸을 찾는 비용이 급격히 커지기 때문에 Load Factor 관리가 훨씬 중요하다. Python의 Dictionary가 Open Addressing 방식을 사용한다.

<br />

## Load Factor와 Resizing

Load Factor는 Hash Table이 얼마나 차 있는지를 나타내는 값으로 `저장된 데이터 수 / Bucket 수`로 계산한다.

Load Factor가 높아질수록 충돌 확률이 올라가서 성능이 O(1)에서 점점 멀어진다. 그래서 대부분의 구현체는 Load Factor가 임계치를 넘으면 Bucket 배열을 2배로 늘리고 모든 데이터를 새 배열에 다시 해싱하는 Resizing(Rehashing)을 수행한다.

```
Java HashMap의 기본 Load Factor 임계치는 0.75다. 16칸짜리 테이블에 13번째 데이터가 들어오는 순간
32칸으로 늘리고 전체를 재해싱한다. Resizing 자체는 O(n)이지만 자주 일어나지 않기 때문에
분할 상환(Amortized) 관점에서는 여전히 O(1)로 취급한다.
```

```
실무에서 대량의 데이터를 Map에 넣을 것을 미리 알고 있다면, 초기 용량(initial capacity)을
지정해서 생성하는 것이 좋다. 중간 Resizing이 반복되는 비용을 아낄 수 있기 때문이다.
```

<br />

## 시간 복잡도 정리

| 연산 | 평균  | 최악 |
| ---- | ----- | ---- |
| 삽입 | O(1)  | O(n) |
| 조회 | O(1)  | O(n) |
| 삭제 | O(1)  | O(n) |

최악의 경우는 모든 Key가 하나의 Bucket으로 충돌하는 상황이다. Hash Function이 잘 설계되어 있고 Load Factor가 관리된다면 사실상 O(1)로 동작한다.

배열/Linked List와 비교하면 아래와 같다.

| 자료구조    | 탐색      | 삽입      | 특징                          |
| ----------- | --------- | --------- | ----------------------------- |
| 배열        | O(n)      | O(1)      | Index 접근은 O(1)             |
| Linked List | O(n)      | O(1)      | 순차 접근만 가능              |
| Hash Table  | O(1)      | O(1)      | 순서 보장 X, 정렬 X           |
| BST         | O(log n)  | O(log n)  | 정렬된 순회 가능              |

Hash Table은 빠르지만 데이터의 순서가 보장되지 않고 범위 검색(range query)이 불가능하다. "특정 Key 하나를 빨리 찾는" 용도에는 Hash Table, "정렬된 순서나 범위가 필요한" 용도에는 Tree 계열이 적합하다. (DB에서 Hash Index가 아닌 B+Tree Index를 기본으로 쓰는 이유이기도 하다.)

<br />

## Typescript로 Hash Table 구현하기

Separate Chaining 방식으로 Hash Table을 구현하면 아래와 같다.

```typescript
class HashTable<V> {
  private buckets: Array<Array<[string, V]>>;
  private size: number;
  private count: number;

  constructor(size = 16) {
    this.buckets = Array.from({ length: size }, () => []);
    this.size = size;
    this.count = 0;
  }

  private hash(key: string): number {
    let hash = 0;
    for (const char of key) {
      hash = (hash * 31 + char.charCodeAt(0)) % this.size;
    }
    return hash;
  }

  set(key: string, value: V): void {
    const index = this.hash(key);
    const bucket = this.buckets[index];

    // 이미 존재하는 Key면 값을 갱신
    for (const entry of bucket) {
      if (entry[0] === key) {
        entry[1] = value;
        return;
      }
    }

    bucket.push([key, value]);
    this.count++;

    // Load Factor가 0.75를 넘으면 Resizing
    if (this.count / this.size > 0.75) {
      this.resize();
    }
  }

  get(key: string): V | null {
    const bucket = this.buckets[this.hash(key)];

    for (const [k, v] of bucket) {
      if (k === key) {
        return v;
      }
    }
    return null;
  }

  delete(key: string): boolean {
    const bucket = this.buckets[this.hash(key)];

    for (let i = 0; i < bucket.length; i++) {
      if (bucket[i][0] === key) {
        bucket.splice(i, 1);
        this.count--;
        return true;
      }
    }
    return false;
  }

  private resize(): void {
    const oldBuckets = this.buckets;
    this.size *= 2;
    this.count = 0;
    this.buckets = Array.from({ length: this.size }, () => []);

    // 기존 데이터를 새 크기 기준으로 전부 재해싱
    for (const bucket of oldBuckets) {
      for (const [key, value] of bucket) {
        this.set(key, value);
      }
    }
  }
}

const table = new HashTable<number>();
table.set("apple", 1000);
table.set("banana", 2000);

console.log(table.get("apple")); // 1000
table.delete("apple");
console.log(table.get("apple")); // null
```

<br />

## JavaScript의 Object vs Map

JavaScript에서 Hash Table이 필요할 때 Object와 Map 중 무엇을 쓸지 고민하게 되는데, 순수하게 Key-Value 저장소로 쓸 것이라면 Map이 낫다.

1. Object는 Key가 string/symbol만 가능하지만, Map은 객체를 포함한 모든 타입을 Key로 쓸 수 있다.
2. Object는 프로토타입 체인을 상속받기 때문에 `constructor`, `toString` 같은 Key가 이미 존재하는 셈이라 충돌 위험이 있다. (이를 노린 Prototype Pollution 공격도 있다.)
3. Map은 삽입 순서를 보장하고 `size`로 크기를 바로 알 수 있으며, 잦은 추가/삭제 시나리오에 최적화되어 있다.

```
외부 입력(사용자 요청의 body 등)을 Key로 사용하는 저장소를 Object로 만들면
"__proto__" 같은 Key가 들어왔을 때 Prototype Pollution으로 이어질 수 있다.
외부 입력을 Key로 다룬다면 Map을 사용하거나 Object.create(null)로 생성하는 것이 안전하다.
```

<br />

## 정리

1. Hash Table은 Hash Function으로 Key를 배열 Index로 변환하여 평균 O(1)의 삽입/조회/삭제를 제공하는 자료구조다.
2. 서로 다른 Key가 같은 Index로 계산되는 Hash Collision은 필연적으로 발생하며, Separate Chaining 또는 Open Addressing으로 해결한다.
3. Load Factor가 임계치(보통 0.75)를 넘으면 Resizing으로 성능을 유지하며, 이 비용은 분할 상환 관점에서 O(1)로 취급한다.
4. 순서와 범위 검색이 필요 없고 단건 조회가 빈번하다면 Hash Table, 정렬/범위가 필요하다면 Tree 계열을 선택한다.
