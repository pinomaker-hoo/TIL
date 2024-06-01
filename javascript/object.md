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
