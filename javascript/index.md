# Javascript

## 개요

Javascript에 대해서 정리합니다.

<br />

## 목차

1. [Hoisting , Scope](#1-hoisting-scope)
2. [Array Method](#2-array-method)

<br />
<br />

## 1. Hoisting, Scope

<br />

### (1) Hoisting

<br />

호이스팅은 변수의 선언만을 해당 스코프의 가장 맨 위로 끌어올리는 것을 의미한다.

```javascript
var x = 1;
console.log(x); // 1
```

```javascript
console.log(x); // undefined
var x = 1;
```

x를 선언하기도 전에 x를 호출 했으나 x를 찾아오긴한다. var를 이용하여 변수를 선언하면 변수를 해당 스코프에서 가장 최상단으로 호이스팅한다. 즉 선언을 가장 위에서 한다고 생각하면 된다.

즉 위의 2번째 코드는 아래와 같다.

```javascript
var x;
console.log(x); // undefined
x = 1;
```

만약에 변수를 선언하지도 못한 상황은 아래와 같이 나와야한다. x에 대해서 선언 조차 안 되어있기에 에러가 나오는 거다.

```javascript
console.log(x); // Reference Error
x = 1;
```

```javascript
// 1
function foo() {
  return "foo";
}
console.log(foo); // foo

// 2
console.log(foo); // foo
function foo() {
  return "foo";
}
```

함수도 호이스팅 대상이라 위의 2개의 코드는 같은 값을 출력한다. 함수의 선언과 값의 초기화는 다르기에 같은 결과를 얻을 수 있다.

### (2) Scope

Scope란 범위를 의미하며 변수에 접근할 수 있는 범위를 의미한다.

코드의 어떤 식별자가 실제로 어떤 값을 가르키는 지 결정하는 것을 binding이라고 하는 데, JS에서는 lexical scope를 통해 이루어진다.

lexical scope는 바깥 쪽에서는 안 쪽의 변수는 참조 할 수 없지만 반대로 안 쪽에서는 바깥 쪽을 참조할 수 있는 것을 의미한다.

참고로 var로 선언하는 것은 block scoping의 대상이 아니라서 아래와 같은 코드처럼 작동한다.

```javascript
var x = 1;
if (true) {
  var x = 2;
}
console.log(x); // 2
```

<br />

## 2. Closure

<br />

```
closure = function + environment
```

클로저는 함수가 하나 생길 때 마다 하나씩 생기며, environment는 함수 자신을 둘러싼 접근할 수 있는 모든 Scope를 의미한다.

<br />

```javascript
function and(x) {
  return function print(y) {
    return x + "and" + y;
  };
}

const saltAnd = and("salt");
console.log(saltAnd("peper")); // salt and peper
console.log(saltAnd("sugar")); // salt and sugar
```

여기서 and 함수로 만들어진 saltAnd의 클로저는 함수 print와 환경인 x => "salt"이다.

클로저는 higher-order function을 만드는 데 유용하다.

<br />

## 3. prototype

<br />

Javascript에서 이제는 Class 키워드가 있지만, 그 전에는 아래와 같이 함수를 이용하여 생성하였고 사실 Class 키워드는 아래의 생성자 함수와 같다.

```javascript
function Student(name) {
  this.name = name;
}

const me = new Student("Pino");
console.log(me); // Student {name : "Pino"}
```

JS의 모든 객체는 자신의 부모 역할을 담당하는 객체와 연결되어있다. 객체지향에서의 상속 개념과 같이 부모 역할을 하는 객체의 프로터티나 메서드를 상속받아 사용할 수 있다.

이러한 부모 객체를 Prototype 객체라고 한다.

```javascript
const student = {
  name: "Pino",
  age: 23,
};

console.log(studnet.hasOwnProperty("name")); // truje
```

위의 코드에서 studnet 객체에는 hasOwnProperty라는 메소드가 없지만 프로토타입인 Object로로부터 상속을 받아 실행된다.

JS에서 모든 객체는 [[Prototype]]이라는 인터널 슬롯을 가진다. 그 값은 null 또는 객체이며 상속을 구현하는 데 사용된다. [[Prototype]] 객체의 프로퍼티는 **proto**로 접근할 수 있지만 수정은 할 수 없다. 객체의 프로토타입은 생성될 때 결정되지만 임의로 변경도 가능하기에 상속을 구현할 수도 있다.

함수도 객체이기에 [[Prototype]] 인터널 슬롯을 가지는 데, 읿반 객체와 달리 prototype 프로퍼티도 소유하게 된다.

[[Prototype]]은 함수를 포함한 모든 객체가 가지고 있는 인터널 슬롯으로 객체 입장에서 자신의 부모 역할을 하는 프로토타입 객체를 가리키며, 함수 객체의 경우 Function.prototype을 가르킨다.

```javascript
console.log(Person.__proto__ === Function.prototype);
```

prototype 프로퍼티는 함수 객체만 가지고 있으며 함수 객체가 생성자로 사용될 때 이 함수를 통하여 생성될 객체의 부모 역할을 하는 객체를 가르킨다.

```javascript
console.log(Person.prototype === foo.__proto__);
```

프로토타입 객체는 constructor 프로퍼티를 갖는다. 이 프로퍼티는 객체의 입장에서 자신을 생성한 객체를 가리킨다. 즉 아래와 같이 동작한다.

```javascript
function Person(name) {
  this.name = name;
}

const foo = new Person("LEE");

// Person() 생성자 함수에 의해 생성된 객체를 생성한 객체는 Person() 생성자 함수다.
console.log(Person.prototype.constructor === Person);

// foo 객체를 생성한 객체는 Person() 생성자 함수다.
console.log(foo.constructor === Person);

// Person() 생성자 함수를 생성한 객체는 Function() 생성자 함수다.
console.log(Person.constructor === Function);
```

<br />

## 2. Array Method

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
