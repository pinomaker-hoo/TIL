# Typescript

## 개요

이 글은 타입스크립트 프로그래밍 책을 읽고 정리한 내용 입니다.

[타입스크립트 프로그래밍 - Boris Czerny](https://product.kyobobook.co.kr/detail/S000001033092)

<br />

## 목차

- [1. Typescript를 사용하는 이유](#1-typescript를-사용하는-이유)
- [2. typescript의-동작-원리](#2-typescript의-동작-원리)
- [3. 타입 시스템](#3-타입-시스템)
  - [(1) 타입이 어떻게 결정되는가](#3-1-타입이-어떻게-결정되는가)
  - [(2) 자동으로 타입이 변환되는가](#3-2-자동으로-타입이-변환되는가)
- [4. 함수](#4-함수)

  <br />

  <br />

## 1. Typescript를 사용하는 이유

<br />

Typescript는 개발자에게 문서화를 제공하고, 리팩터링을 쉽게 만들며, 단위 테스트의 숫자를 절반으로 줄일 수 있어 더 안전한 프로그램을 구현할 수 있게 보장한다.

여기서 "안전한"이라는 단어는 타입 안전성을 의미한다.

```
타입 안전성 (type safety)
타입을 이용해 프로그래밍이 유효하지 않은 작업을 수행하지 않도록 방지한다.
```

아래의 예시들은 유효하지 않은 작업에 대한 예시다.

- 숫자와 리스트를 곱한다.
- 객체에 존재하지 않는 멤버 함수를 호출한다.

일부 언어들은 이런 오류가 발생하는 코드들이더라도 최대한 실행할려고 노력한다. 그 중 하나가 Javascript로 예시를 한 번 보자.

```javascript
3 + []; // "3"으로 평가

let obj = {};
obj.foo; // undefiend로 평가

function a(b) {
  return b / 2;
}
a("Z"); // NaN으로 평가
```

분명히 잘못된 동작이지만 Javascript는 예외를 던지지 않고 결과를 도출한다. 이러한 문제를 바로 잡기 위하여 Typescript가 등장하였고 Typescript는 에러를 알려준다는 사실도 훌륭하지만 코드를 작성한 순간 바로 에러를 알려주는 것이 개발자에게 매우 좋은 경험을 제공한다.

<br />

## 2. Typescript의 동작 원리

<br />

이번 목차에서는 Typescript Compiler(TSC)의 동작 원리에 대해서 알아보고자 한다.

프로그램은 프로그래머가 작성한 다수의 텍스트 파일로 구성되며 이 파일들을 컴파일러라는 특별한 프로그램이 파싱하여 추상 문법 트리(AST)라는 자료 구조로 변환한다.

이 AST는 공백, 주석, 탭등을 완전히 무시하고 다시 컴파일러는 AST를 바이트코드라는 하위 수준의 표현으로 변환하고, 이를 runtime이라는 다른 프로그램에 바이트 코드를 입력하여 평가하고 결과를 얻을 수 있다.

```
1. 프로그램이 컴파일러에 의하여 AST로 파싱된다.
2. AST는 다시 컴파일러에 의하여 바이트코드로 컴파일된다.
3. Runtime이 바이트코드르 평가한다.
```

여기서 Typescript가 다른 언어와 다른 점은 컴파일러가 코드를 바이트코드 대신에 Javascript 코드로 변환하게 된다. 이 때 TSC는 AST를 만들어 결과 코드를 내놓기 전에 타입 확인을 거치게된다.

```
타입 검사기(Typechecker)
코드의 타입 안전성을 검증하는 특별한 프로그램
```

[
![images_ggob_2_post_be680c2c-123b-473a-9cf0-4906ca18fb58_TSC](https://github.com/pinomaker-hoo/TIL/assets/56928532/c43ff164-83d6-40fb-9a17-98182de179ce)
](url)

<br />

## 3. 타입 시스템

<br />

```
타입 시스템(Type system)
타입 검사기가 프로그램에 타입을 할당하는 데 사용하는 규칙 집합
```

타입 시스템은 보통 어떤 타입을 사용하는 지 컴파일러에 명시적으로 알려주는 타입 시스템과 자동으로 타입을 추론하는 타입 시스템인 2가지로 구분된다.

타입 스크립트는 두 가지 시스템 모두의 영향을 받았기에 명시적으로 타입을 지정하거나 타입을 추론하는 방식 중에서 선택 할 수 있다.

```typescript
const a: number = 3;
const b: string = "Hello world";
const c: boolean[] = [true, false];

const d = 3; // number로 추론
const e = "Hello world"; // string으로 추론
```

하지만 타입스크립트가 타입을 추론하도록 두는 것이 코드를 줄일 수 있는 방법이라 보통은 타입을 추론하게 두는 편이다.

| 타입 시스템 기능 | javascript | typescript   |
| ---------------- | ---------- | ------------ |
| 타입 결정 방식   | 동적       | 정적         |
| 타입 자동 변환   | O          | X            |
| 타입 확인 시기   | runtime    | compile time |
| 에러 검추 시기   | runtime    | compile time |

<br />

### 3-1. 타입이 어떻게 결정되는가?

<br />

Javascript는 동적 타입 바인딩(Dynamic type binding)이라 프로그램을 실행해야만 특정 데이터의 타입을 확인 할 수 있음을 의미한다.

Typescript는 점진적으로 타입을 확인해야하는 언어다. 즉 타입 스크립트는 컴파일 타임에 프로그램의 모든 타입을 알고 있을 때 최상의 결과를 보여줄 수 있지만 컴파일 할 때 모든 타입을 반드시 알아야하는 것은 아니다.

점진적 타입 확인은 타입을 지정하지 않은 기존 Javascript를 Typescript로 마이그레이션할 때 유용하다. 하지만 그런 상황이 아니라면 모든 코드의 타입을 컴파일 타임에 지정하는 것을 목표로 해야한다.

<br />

### 3-2. 자동으로 타입이 변환되는가?

<br />

Javascript는 약한 타입의 언어이기에 아까 했던 것과 같이 유효하지 않은 연산을 수행해도 최대한 실행할려고 노력하기에 아래와 같이 평가하게 된다.

```javascript
3 + [1]; // "31"으로 평가
```

위의 예시처럼 Javascript는 영리하게 타입을 변환하려 노력하지만 Typescript는 유효하지 않은 작업을 발견하면 예외를 던지게된다.

```tavascript
3 + [1] // '+' 연산자를 '3'과 [1]에 사용할 수 없다.
```

올바르지 않아 보이는 연산을 수행하면 Typescript는 예외를 던지지만 Javascript는 예외를 던지지 않고 자동 변환하여 문제를 발생시키고 이를 추적하기 어렵게 만든다. 이런 부분 때문에 Typescript를 이용하여 타입을 체크하는 것이 좋다.

<br />

## 시스템의 Type

<br />

타입이란 단순하게 정수형, 문자열형만 있는 것이 아닌 그것을 포함한 그것으로 할 수 있는 모든 연산을 포함한다.

```
타입 (Type)
값과 이 값으로 할 수 있는 일의 집합
```

- Boolean Type은 모든 불과 불에 수행할 수 있는 모든 연산(||, &&, !)의 집합이다.

- number type은 모든 숫자와 숫자에 적용할 수 있는 모든 연산(+, -)뿐만 아니라 숫자에 호출할 수 있는 모든 메서드(.toFixed, .toString)도 포함된다.

어떤 값이 T 타입이라면 그 값을 아지고 어떤 일을 할 수 있는 지 어떤 일을 할 수 없는 지 알 수 있다. 여기서 중요한 것은 타입 검사기를 이용하여 유효하지 않은 동작이 실행되는 일을 방지하는 것이다.

![img](https://github.com/pinomaker-hoo/TIL/assets/56928532/4e5c83fe-98d9-41a7-9b97-cd533cda8f8b)

<br />

### (1) any

<br />

any는 뭐든 지 할 수 있지만 꼭 필요한 상황이 아니라면 사용하지 않는 것을 추천한다. 타입의 정의는 값과 그 값으로 할 수 있는 모든 작업의 집합인데, any는 모든 값의 집합이기에, 모든 것을 할 수 있어 Javascript와 같이 사용하는 것이다.

<br />

### (2) unknown

<br />

만약 내가 어떤 타입인지 미리 알 수 없는 값이라면 any 대신에 unknown을 사용하자. any처럼 모든 값을 대표하지만 타입을 검사하여 정제하기 전까진 타입스크립트가 unknown 타입의 값을 사용할 수 없도록 강제한다.

```typescript
const a: unknown = 30;
const b = a + 10; // Error, 객체의 타입이 unknow이다.

if (typeof a === "number") {
  const c = a + 10; // 40
}
```

위의 예제와 같이 사용하여 어떤 값이 들어올 지 모르는 상황을 대비할 수 있다.

<br />

### (3) boolean

<br />

boolean은 true(참), false(거짓) 두 개의 값을 가지고 있으며, 이 값들을 가지고 비교 연산(==, ===)과 반전 연산(!), 논리 연산(&&, ||)을 할 수 있다.

```typescript
const a = true; // boolean
const b = false; // boolean
const c: false = false; // boolean
const d: true = false; // Error, true에 false 삽입 불가
```

타입스크립트는 4가지의 경우로 boolean인지 판단이 가능하다.

1. 어떤 값이 boolean인지 추론하게한다.
2. 어떤 값이 특정 boolean인지 추론하게 한다.
3. 어떤 값이 boolean인지 명시한다.
4. 어떤 값이 boolean의 특정 값이라고 명시한다.

실제로는 보통 1번과 2번을 사용하는 데, 드물게 타입 안정성을 목적으로 4번을 사용할 때도 있다. 다른 언어에 비하여 특이한 점은 특정 타입으로 선언하는 것이 아닌 값으로 타입 선언이 가능하다는 점이고, 이 부분을 타입 리터럴이라고 한다.

```
타입 리터럴(type literal)

오직 하나의 값을 나타내는 타입
```

<br />

### (4) number

<br />

number 타입은 모든 숫자(정수, 소수, 양수, 음수, NaN 등)의 집합이다. 이 값들을 이용하여 덧셈, 뺄셈, 비교 등의 연산도 가능하다.

```typescript
const a = 100;
const b: number = 30;
const c: 30.5 = 30.5;
const d: 30.5 = 10; // error, 30.5에 10 할당 불가능
```

number 타입은 boolean과 마찬가지로 타입 리터럴이 사용 가능하며 보통 사용할 때는 number 타입을 추론하게 만들게 사용한다.

참고로 긴 숫자를 처리할 때는 숫자 분리자를 이용하여 가독성을 높일 수 있다. 숫자 분리자는 타입과 값에 모두 사용 가능하다.

```typescript
const a = 1_000_000;
const b: 1_000_000 = 1_000_000;
```

<br />

### (5) bigint

<br />

bigint는 JS와 TS에 새롭게 추가된 타입으로, 이를 이용하면 라운딩 관련 에러 걱정 없이 큰 정수를 표현할 수 있다.

number는 254까지의 정수를 표현할 수 있지만 bigint를 사용하면 더 큰 수를 처리할 수 있지만 아직 일부 JS 엔진에서 지원하지 않는 경우가 있다.

```typescript
const a = 1234n; // bigint
const b = 1234; // number
```

<br />

### (6) string

<br />

string은 모든 문자열의 집합으로 연결(+), 슬라이스(.slice)등의 연산을 수행할 수 있다. number 등과 마찬가지로 4가지 방법으로 선언이 가능하며, string을 추론하게 사용하는 것이 좋다.

```typescript
const a = "Hello world";
const b: string = "hello";
```

<br />

### (7) symbol

<br />

symbol 타입은 ES2015에 새로 추가된 기능으로, 실무에서 자주 사용하지는 않는다. 객체와 Map 등에서 문자열 키를 대신하는 용도로 사용한다. 심벌키를 사용하면 사람들이 잘 알려진 키만 사용하도록 상제할 수 있어 키를 잘못 설정하는 실수를 방지 할 수 있다.

객체의 기본 반복자를 설정하거나 객체가 어떤 인스턴스인지를 런타임에 오버라이딩 하는 것과 비슷한 기능을 제공한다. symbol 타입으로는 할 수 있는 동작이 별로 없다.

```typescript
const a = Symbol("a");
const b: symbol = Symbol("b");
```

JS에서 Symbol("a")는 주어진 이름으로 새로운 symbol을 만든다는 의미이며, 만들어진 symbol은 고유하기에 다른 symlbol과 "=="과 "==="로 비교했을 때 같지 않는다고 판단된다.

<br />

### (8) 객체

<br />

Typescript에서 객체(Object) 타입은 객체의 형태를 정의한다. 재미있는 부분은 객체 타입으로만은 {}로 만든 객체와 new로 만든 객체를 구분할 수 없다.

이는 JS가 구조 기반 타입을 갖게 설계되었기 때문에 TS도 이름 기반 타입이 아닌 구조 기반의 타입을 선호한다.

```
구조 기반 타입화

구조 기반 타입화에서는 객체의 이름에 상관없이 객체가 어떤 프로퍼티를 갖고 있는 지를 따진다. 일부 언어에서는 이를 덕 타이핑(duck typing)이라고한다.
```

### (9) 타입 별칭

우리는 let, const를 이용하여 변수를 선언하는 것과 같이 타입 별칭을 이용하여 타입을 선언할 수 있다.

```typescript
type Age = number;
type Person = {
  name: string;
  age: Age;
};

const minwoo : Person = {
  name "minwoo",
  age : 20
}
```

타입 별칭은 변수 선언과 같이 하나의 타입을 두 번 선언할 수 없으며, 블록 영역에 선언이 해당된다.

<br />

### (10) 유니온과 인터섹션

<br />

A, B라는 두 사물이 있을 때 이의 영역을 합친 합집합을 유니온, 겹치는 부분인 교집합을 인터섹션이라고한다.

타입 스크립트에서는 타입에 적용할 수 있는 특별한 연산자인 유니온과 인터섹션을 제공한다.

```typescript
type Cat = { name: string; color: string };
type Dog = { name: string; color: string; age: number };

type CatOrDog = Cat | Dog; // 유니온
type CatAndDog = Cat & Dog; // 인터섹션
```

<br />

### (11) 배열

<br />

타입스크립트에서의 배열은 연결, 푸시, 검색, 슬라이스 등을 지원하는 특별한 객체 중 하나다.

```typescript
const a = [1, 2, 3]; // number[]
const b = ["1", "2"]; // string[]
const c = [1, 2, "3"]; // (string | number)[]
```

Typescript에서는 T[]와 Array<T>라는 두가지의 배열 문법을 지원하고 성능 및 의미상은 같다. 필자는 T[]를 주로 사용한다.

보통 배열을 만들 때는 여러가지의 타입이 들어간 배열이 아닌 동형성의 배열 즉 같은 타입을 가진 배열을 만드는 것이 일반적이다. 그 이유는 배열을 연산할 때 각 타입이 가지고 있는 메서드가 각기 다르기 때문이다.

<br />

### (12) 튜플

<br />

튜플은 배열의 서브타입으로, 길이가 고정되어있고 각 인덱스의 타입이 알려진 배열의 일종이다. 튜플은 타입을 추론하는 것이 아닌 명시해야하는 것이 특징이다.

```typescript
const a: [number] = [1];
const b: [number, string, number] = [10, "name", 30];
```

튜플은 아래와 같이 선택형 요소도 사용할 수도 있다.

```typescript
const a: [number, number?][] = [[1], [1, 2]];
```

일반 배열은 가변이기에 작업을 자유롭게 수행할 수 있는 반면에 상황에 따라서 읽기 전용 배열인 불변성 배열이 필요할 수도 있다.

Typescript에서는 readonly타입의 배열을 기본으로 지원하기에 이를 이용하여 읽기 전용 배열을 생성할 수도 있다.

```typescript
const a: readonly number[] = [1, 2, 3];

a[4] = 5; // Error, 읽기 전용이라 수정 불가
```

<br />

### (13) null, undefiend, void, never

<br />

Javascript는 null, undefined를 이용하여 부재를 표한하며 Typescript도 두 가지를 이용한다.

null과 undefiend는 당연하게도 다른 점이 있는 데 null은 빈 값을 의미ㅏ며 undefined는 아직 정의하지 않는 값을 의미한다.

Typescript는 null과 undefined를 제외하고도 void와 never 타입도 제공하는 데 이를 이용하여 좀 더 세밀하게 특징을 분류할 수 있다.

void는 아무것도 반환하지 않는 함수의 반환 타입이며, never는 절대 반환하지 않는 함수 타입을 가르킨다.

```typescript
// null 혹은 number를 리턴
const a = (a: number) => {
  return a > 10 ? 30 : null;
};

// undefined 리턴
const b = () => undefined

// never 리턴
const c = () => throw TypeError("ERROR")

// void 리턴
const d = () => {
  console.log("Hello world")
}
```

<br />

### (14) 열거형

<br />

열거형은 해당 타입으로 사용할 수 있는 값을 열거하는 기법으로 키를 값에 해당하는 순서가 없는 자료구조다.

```typescript
enum Animal {
  LION,
  CAT,
  DOG,
}
```

열거형의 이름은 단수 명사로 쓰고 첫 문자는 대문자로 하는 것이 관례이며 키도 첫 글자를 대문자로 표현한다.

또한 키에 값을 명시적으로 할당할 수도 있다.

```typescript
enum Animal {
  LION = 0,
  CAT = 1,
  DOG = 2,
}
```

<br />

## 4. 함수

<br />
Javascript에서 함수는 일급 객체다. 즉 객체를 다루듯이 함수를 변수에 할당하거나 다른 함수로 전달하거나 함수에서 함수를 반환하는 등의 작업을 할 수 있다.

```typescript
const add = (a : number, b : number) {
  return a + b
}
```

Typescript에서 함수를 사용할 떄는 보통 매개변수의 타입은 명시적으로 정의한다. 타입 스크립트는 항상 함수 본문에서 사용된 타입들을 추론하지만 특별한 경우를 제외하고는 매개변수의 타입은 추론하지 않는다. 보통 반환 타입은 추론하게두지만 명시도 가능하다.

```typescript
const add = (a : number, b : number) : number {
  return a + b
}
```

함수는 다양한 방법으로 생성할 수 있는 데 함수 생성자로 함수를 생성하는 것은 타입에 있어서 안전하지 않기에 권장하지 않는다.

<br />

### (1) 선택적 매개변수와 기본 매개변수

<br />

함수에서 ?를 이용하여 선택적 매개변수를 지정할 수 있다. 함수의 매개변수를 선언할 때 ?를 이용하여 선택적 매개변수를 선언한다.

```typescript
const log(message : string, userId ?: number) => {
  console.log(message, userId || "Not Found UserID" )
}
```

또한 JS와 마찬가지로 매개변수에 기본 값을 지정할 수 있다. 매개변수에 값을 전달하지 않아도 되기에, 선택적 매개변수를 선언하는 것과 같다.

```typescript
const log(message : string, userId = "Not Found UserID") => {
  console.log(message, userId)
}
```

<br />

### (2) 나머지 매개변수

<br />

인수를 여러 개 받는 함수라면 배열 형태로 목록을 넘길 수도 있다.

```typescript
const sum = (numbers: number[]): number => {
  return numbers.reduce((ocr, cur) => ocr + cur, 0);
};

sum([1, 2, 3]); // 6
```

<br/>

떄론 고정 인자 API가 아니라 가변 인자 API가 필요할 때가 있는 데, JS에서는 이를 arguments 객체를 통하여 기능을 제공했다. 하지만 arguments는 순수 배열이 아니기에 reduce와 같은 내장 기능을 사용할려면 배열로 변환해야한다.

<br/>

```typescript
const sum2 = (): number => {
  return Array.from(arguments).reduce((ocr, cur) => ocr + cur, 0);
};

sum2(1, 2, 3); // 6
```

<br/>
다만 arguments 객체는 안전하지 않다. Typescript에서는 ocr과 cur을 모두 any로 타입을 추론하게 되며, 함수를 호출하게 될 때는 TypeError를 발생시킨다.

이러한 문제는 나머지 매개변수로 아래와 같이 해결한다.

<br />

```typescript
const sum3 = (...numbers: number[]): number => {
  return numbers.reduce((ocr, cur) => ocr + cur, 0);
};

sum2(1, 2, 3); // 6
```

<br />

이렇게 선언하면 타입 안정성을 갖추게 되었고, 내장 메서드도 사용 가능해졌다.

<br />

### (3) call, apply, bind

<br />

함수를 호출하는 방법은 ()를 이용하는 것도 있지만, apply와 call, bind를 활용하는 방법도 있다.

```typescript
const add = (a: number, b: number) => {
  return a + b;
};

add(10, 20);
add.apply(null, [10, 20]);
add.call(null, 10, 10);
add.bind(null, 10, 20)();
```

apply는 함수 안에서 값을 this로 한정하며, 두번째 인수를 펼쳐서 매개변수로 전달하고 call도 비슷하지만 인수를 펼치지 않고 순서대로 전달한다는 차이점이 있다.

bind는 함수를 호출하는 것이 아니라 새로운 함수를 반환하기에 한정하지 않은 매개변수를 추가로 전달할 수 있다.
