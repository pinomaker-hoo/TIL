# Reflect

Reflect는 Proxy와 같이 Javascript 명령을 가로챌 수 있는 메서드를 제공하는 내장 객체이며, Proxy Handler의 모든 Trap을 Reflect의 내장 메서드가 동일한 인터페이스로 지원된다.

## Reflection

스스로 메타언어가 되어 자기 자신을 프로그래밍(메타 프로구래밍)할 수 있는 언어가 되는 것

```javascript
const say = () => {};

console.log(say.name); // say

say.name = "hello";

console.log(say.name); // say
```

위의 코드를 보면 say라는 함수를 선언하고 그 함수의 이름을 변경하려고 하지만 변경이 되지 않는 것을 볼 수 있는 예제다.

해당 예제를 통해 함수의 이름이 readonly로 설정되어있기에 수정할 수 없다는 것을 알 수 있다. 또한 어딘가에 name 필드가 수정될 수 없다는 정보가 저장되어있다는 뜻이기도 한데, 이는 getOwnPropertyDescriptor를 이용하여 확인할 수 있다.

```javascript
console.log(Reflect.getOwnPropertyDescriptor(say, "name"));

// {
//   value: 'say',
//   writable: false,
//   enumerable: false,
//   configurable: true
// }
```

say라는 이름은 writable이 false로 설정되어 있기에 값을 변경할 수 없지만 name 필드를 변경할 수 없다 자체를 수정할 수 있습니다.

```javascript
Reflect.defineProperty(say, "name", {
  writable: true,
});

say.name = "hello";

console.log(say.name); // hello
```

자 위의 코드를 보면 Reflect의 defineProperty를 이용하여 writable 값을 true로 수정해준 say의 name조차도 수정할 수 있는 것을 볼 수 있다.

이 처럼 프로그램을 통해 자기 자신을 프로그래밍하는 것을 메타 프로그래밍이라고한다.

### Reflect 한계

Reflect를 통해 이미 JS에 정의된 속성을 다룰 수 있게 되었지만, 이것만으로는 특정 어플리케이션에서 다루는 데이터를 프로그램 수준에서 저장할 수 없다는 한계가 있고 이를 극복하기 위해 나온 라이브러리가 reflect-metadata라고 합니다.

메타데이터에 저장할 내부 슬릇을 추가하고 접근할 수 있는 Reflect API에 대한 제안이 있었지만 아직 수용되지 않았고 그 전에 해당 라이브러리가 나왔다고 합니다.
