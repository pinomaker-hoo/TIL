## prototype

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
