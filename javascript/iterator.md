# 리스트 순회

Javascript에는 Array, Map, Set과 같은 다양한 리스트가 있는 데 이를 순회하기 위해서는 어떻게 해야할까?

바로 forof를 사용할 수 있다.

```javascript
// Array
const arr = [1, 2, 3];
for (const _ of arr) {
  console.log(_); // 1, 2, 3
}
```

```javascript
// Map
const arr = new Set([1, 2, 3]);
for (const _ of arr) {
  console.log(_); // 1, 2, 3
}
```

```javascript
// Array
const arr = new Map([
  ["a", 1],
  ["b", 2],
  ["c", 3],
]);
for (const _ of arr) {
  console.log(_); // ["a", 1], ["b", 2], ["c", 3],
}
```

위의 코드를 보면 forof를 사용하여 3개의 리스트에 대해서 순회를 하는 것을 볼 수 있는 데 이 때 우리는 index를 사용하여 각 요소에 접근하는 것이 아니다. 기본적으로 Set과 Map에는 index가 없다.

하지만 우리는 이터러블과 이터레이터 개념을 사용하여 forof를 이용해 리스트 순회가 가능하다.

이터러블 : 이터레이터를 리턴하는 [Symbol.iterator]()를 가진 값

이터레이터 : {value, done} 객체를 리턴하는 next()를 가진 값

이터러블/이터레이터 프로토콜 : 이터러블을 for of, 전개 연산자 등과 동작하도록한 규약

즉 Array, Map, Set을 forof를 사용하여 순회할 수 있었던 이유는 해당 객체들이 {value, done} 객체를 리턴하는 next()를 가진 값을 리턴하는 Symbol.interator()를 가진 이터러블이기 때문이다.

### Custom Iterator / Iterable

forof문은 이터러블/이터레이터 프로토콜을 기반으로 작동한다. 그렇다면 우리가 만드는 객체가 해당 프로토콜을 사용하면 forof를 사용할 수 있을까? 정답은 Yes다.

```javascript
const iterable = {
  [Symbol.iterator]() {
    let i = 5;
    return {
      next() {
        return i == 0 ? { done: true } : { value: i--, done: false };
      },
    };
  },
};

for (const _ of iterable) {
  console.log(_); // 5, 4, 3, 2, 1
}
```

forof를 실행하게 되면 [Symbol.iterator]()를 사용하여 이터레이터를 반환하고 next()를 호출하여 내가 만든 커스텀 객체도 순회할 수 있게된다.

### 전개연산자

```javascript
const arr = [1, 2, 3];

console.log([...arr, ...[1, 2, 3]]);
```

위의 코드는 우리가 흔하게 사용하는 전개 연산자인데 해당 연산자도 사실 이터러블과 이터레이터 프로토클을 기반으로 작동하게 된다.
