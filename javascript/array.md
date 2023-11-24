## Array Method

<br />

### (1) sort

<br />

sort는 배열을 오름차순이나 내림차순으로 정리할 수 있는 메서드다.

```javascript
arr.sort([compareFunction]);
```

위의 구조와 같이 사용할 수 있는 데, 먼저 compareFunction에는 정렬 순서를 정의하는 함수를 넘길 수가 있으며, 만약 생략될 경우에는 배열의 요소들이 문자열로 취급되어 유니코드 값 순서대로 정렬된다.

이 함수는 2개의 배열 요소를 파라미터로 받는다. 만약에 a,b를 파라미터로 넘길 경우 이 함수가 리턴하는 값이 0보다 작으면 a가 b보다 앞으로 오도록 정렬하고, 0보다 크면 b가 a보다 앞에 오도록 정렬한다. 참고로 0을 리턴하면 정렬하지 않는다.

이 함수는 compareFunction의 규칙에 의하여 정렬된 배열을 리턴하는 데, 새로운 배열을 복사하여 주는 것이 아니라 원본 배열이 정렬이 되고 리턴하는 값도 원본 배열을 가르킨다.

```javascript
const arr = [2, 1, 3];
console.log(arr.sort()); // [1, 2, 3]
```

위의 예시를 보면 sort에 compareFunction을 정의하지 않아 유니코드를 기준으로 정렬되었다.

```javascript
const arr = [2, 1, 3, 10];
console.log(arr.sort()); // [1, 10, 2, 3]
```

위의 예시를 보면 우리가 기대한 값인 [1,2,3,10] 이 아닌 [1,10,2,3]으로 나오는 것을 볼 수 있는 데 이는 요소를 문자열로 취급하고 유니코드 순서에 따라서 정렬했기 떄문이다.

따라서 숫자를 오름차순하거나 내림차순 할려면 아래와 같이 한다.

```javascript
const arr = [2, 1, 3, 10];
console.log(arr.sort((a, b) => a - b)); // [1,2,3,10]

console.log(arr.sort((a, b) => b - a)); // [10,3,2,1]
```

sort를 이용하면 문자열 정렬도 가능하고, 대소문자 구분 없이 정렬도 가능하다.

```javascript
const arr = ["banana", "b", "Boy"];
console.log(arr.sort()); // ["Boy", "b", "banana"]
```

```javascript
const arr = ["banana", "b", "Boy"];

arr.sort((a, b) => {
  const upperCaseA = a.toUpperCase();
  const upperCaseB = b.toUpperCase();

  if (upperCaseA > upperCaseB) return 1;
  if (upperCaseA < upperCaseB) return -1;
  if (upperCaseA === upperCaseB) return 0;
});

console.log(arr); // ['b', 'banana', 'Boy']
```

또한 비슷한 원리로 객체도 가능하다.

```javascript
const arr = [
  { name: "banana", price: 3000 },
  { name: "apple", price: 1000 },
  { name: "orange", price: 500 },
];

arr.sort(function (a, b) {
  return a.price - b.price;
});
```

(2) join, split, reverse
3개의 메서드는 배열을 문자열로 바꾸거나, 반대로 하거나, 배열의 순서를 뒤집는 메소드다.

1.  join

    배열을 문자열로 변환한 값을 리턴하는 함수다.

    ```javascript
    const arr = ["a", "b", "c"];
    console.log(arr.join()); // abc
    ```

    join에 넘기는 파라미터는 배열 요소를 문자열로 바꿀 때 요소들의 사이에 문자열을 넣을 수 있다.

    ```javascript
    const arr = ["a", "b", "c"];
    console.log(arr.join("-")); // a-b-c
    ```

2.  split

    문자열을 배열로 변환한 값을 리턴한는 함수다.

    ```javascript
    const str = "abc";
    console.log(str.split()); // ["a", "b", "c"]
    ```

    join과 비슷하게 구분자를 기준으로 쪼개서 배열을 만들 수도 있다.

    ```javascript
    const str = "a-b-c";
    console.log(str.split("-")); // ["a", "b", "c"]
    ```

3.  reverse

    배열의 아이템 순서를 뒤집는 메소드로, 주의해야할 점은 새로운 배열을 리턴하는 것이 아니라 원본 배열을 수정한다는 것이다.

    ```javascript
    const arr = [1, 2, 3];
    const response = arr.reverse();
    console.log(response); // [3,2,1]
    console.log(arr); // [3,2,1]
    ```
