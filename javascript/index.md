# Javascript

## 개요

Javascript에 대해서 정리합니다.

<br />

## 목차

[1.Javascript의 이벤트 루프 모델](#1-javascript의-이벤트-루프-모델)

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
