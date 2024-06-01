## 객체(Object)란?

<br />

Javascript는 객체 기반의 스크립트 언어이며 원시타입을 제외한 나머지 값들은 전부 객체이다. 즉 함수, 베열, 정규 표현식도 객체다. Javascript의 객체는 Key와 Value로 구성된 Property의 집합이며, 프로퍼티의 값으로는 Javascript에서 사용할 수 있는 모든 값을 사용할 수 있다.

객체 내에 존재하는 값이 함수일 경우에는 일반 함수와 구별하기 위하여 메소드라고 부른다. 즉 Javascript의 객체는 데이터를 의미하는 프로퍼티와 데이터를 참조하고 동작을 의미하는 메소드로 구성된 집합이다.

```javascript
const person = {
  name: "pinomaker", // 데이터
  say: () => console.log("Hello World"), // 메소드
};
```

## 객체 생성 방법

Java와 같이 Class 기반의 객체지향언어는 new 연산자를 사용하여 인스턴스를 생성하는 방식으로 객체를 생성하는 데, Javascript는 원래 Class란 개념이 없었고(현재는 ES6에서 추가됨), 프로토타입 기반 객체 지향 언어이기에 별도의 객체 생성 방법이 존재한다.

### 객체 리터럴

가장 일반적인 객체 생성 방식으로 {}를 사용하여 생성할 수 있으며, {} 내에 프로퍼티를 작성하면 그 프로퍼티가 추가된 객체를 생성하며 빈 값으로도 생성 가능하다.

```javascript
const obj = {};

const person = {
  name: "pinomaker",
};
```

### Object 생성자 함수

new 연산자와 Object 생성자 함수를 이용하여 빈 객체를 생성 가능하다.

```javascript
const person = new Object();

person.name = "pinomaker";
```

생성자 함수를 이용하여 객체를 생성하는 것은 편하다고 생각하지 않은 데, 알아보니 객체 리터럴 방식으로 생성된 객체는 사실 Built-in 함수인 Object 생성자 함수로 객체를 생성하는 것을 단순화한 축약 표현이라고 한다.

### 생성자 함수

생성자 함수를 사용하면 객체를 생성하기 위한 템플릿 혹은 클래스처럼 사용하여 객체를 편하게 여러개 생성할 수 있다.

```javascript
const Person = (name) => {
  this.name = name;
};

const user = new Person("pinomaker");
```

생성자 함수 이름은 대문자로 시작하는 데 이는 생성자 함수임을 인식하게 도와주며, 프로퍼티 앞에 기술한 this는 생성자 함수가 생성할 인스턴스를 가르킨다. 참고로 this에 연결된 프로퍼티와 메소드는 외부 참조가 가능하지만, 생성자 함수 내에 선언된 변수는 외부 참조가 불가능하다.

```javascript
const Person = (name) => {
  const age = 20;
  this.name = name;
};

const user = new Person("pinomaker");

console.log(user.name); // pinomaker
console.log(user.age); // undefined
```

## 객체 프로퍼티 접근

앞서 말한대로 객체는 값과 키로 구성되어있다. 여기에서 키는 일반적으론 문자열을 지정하며, 문자열이나 symbol이외의 값을 지정하면 타입이 문자열로 변환된다. 프로퍼티 키는 문자열이기에 따옴표를 사용하지만 Javascript에서 사용 가능한 값일 경우는 따옴표를 생략 할 수 있다.

```javascript
const person = {
  "first-name": "pino", // first-name은 연산자가 포함되어있기에 문자열로 감쌈.
  age: 20, // age는 사용 가능
};
```

참고로 변수 선언을 아래와 같이 변수를 프로퍼티 키로 사용이 가능하다.

```javascript
const key = "age";

const person = {
  [key]: 20,
};
```

프로퍼티 키를 이용하여 값을 가져오는 방식은 마침표 표기법과 대괄호 표기법 2개를 사용할 수 있다.

```javascript
const person = {
  name: "pinomaker",
  age: 20,
};

console.log(person.name);
console.log(person[age]);
```

## Pass-by-reference

Object의 Type을 객체 타입 혹은 참조 타입이라고 하는 데 참조 타입은 객체의 모든 연산이 실제값이 아닌 참조값으로 처리됨을 의미한다. 원시 타입 값은 한 번 정해지면 변경할 수 없지만 객체는 프로퍼티를 변경 추가가 가능하다.

즉 객체 타입은 동적으로 변화할 수 있기에 메모리 공간을 얼마나 확보해야하는 지 예측할 수 없기에 런타임에 메모리 공간을 확보하고 메모리의 힙 영역에 저장된다.

```javascript
const pino = {
    age : 20;
}

const maker = pino

console.log(pino.age, maker.age) // 20 20
console.log(pino === maker) // true

maker.age = 30;

console.log(pino.age, maker.age) // 30 30
console.log(pino === maker) // true
```

pino 객체를 리터럴로 생성하였다. 이 때 pino는 객체 자체를 저장하는 게 아니라 생성된 객체의 참조값을 저장하고 있다. 그 후에 maker에 pino를 할당하게 되면 pino가 바라보는 객체 참조값이 maker에 저장되게 된다.

즉 동일한 객체를 참조하기에 두 변수 모두 하나만 변경하더라도 같은 프로퍼티값을 참조하기에 결과가 같아진다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/89b00be7-e4e0-4564-ad87-591be3c27831)

## Pass by value

원시 타입은 값으로 전달된다. 즉 변수에 다른 값을 전달할 때 복사가 되기에 참조와 다르다. 원시 타입은 값이 한 번 정해지면 변경할 수 없기에 이들 값은 런타임(변수 할당 시점)에 메모리 스택 영역에 고정된 메모리 영역을 점유하고 저장한다.

## Object의 종류

Built-in Object는 웹 페이지등을 표현하기 위한 공통된 기능을 제공한다. 웹페이지가 브라우저에 로드되자마자 바로 사용이 가능하며 이는 Standard Built-in Object, BOM, DOM으로 나누어질 수 있다. 또한 사용자가 직접 생성한 객체는 Host Object라고 정의한다.

![image](https://github.com/pinomaker-hoo/TIL/assets/56928532/adf0e519-e9e1-45d9-9c4b-8b460866d918)
