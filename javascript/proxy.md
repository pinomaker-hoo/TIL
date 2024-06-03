# Proxy

Proxy는 특정 객체를 감싸 프로퍼티 읽기, 쓰기와 같은 객체에 가해지는 작업을 중간에 가로채는 객체로 가로챈 작업은 Proxy에서 처리하거나 원래 겍체가 처리하도록 전달하는 역할을 한다.

```javascript
const proxy = new Proxy(target, handler);
```

프록시는 대상인 target과 동작을 가로채는 메서드 Trap이 담긴 객체 입니다. 주로 get trap과 set trap을 많이 사용합니다.

```javascript
const target = {};

const proxy = new Proxy(target, {});

proxy.test = 5;

console.log(target.test); // 5
console.log(proxy.test); // 5

for (let key in proxy) console.log(key); // test
```

위의 코드를 보면 proxy에 trap이 없기에 proxy에 가해지는 모든 작업은 target에 전달되어 처리되게 됩니다.

### Get Trap

Get 메서드는 프로퍼티를 읽을려고 할 때 작동하게 됩니다. 이 때 target과 property, reciver를 매개변수로 받게 되는 데 target은 Proxy의 대상 객체를 의미하고 property는 접근할 때 사용하는 key, reciver는 target property가 getter라면 this를 의미하게 된다고 합니다.

```javascript
const nums = [1, 2, 3];

const proxyNums = new Proxy(nums, {
  get(target, prop) {
    if (prop in target) {
      return target[prop];
    } else {
      return 0;
    }
  },
});

console.log(proxyNums[1]); // 2
console.log(proxyNums[123]); // 0
```

자 위의 예제를 보면 handler 부분에 get 메서드를 작성한 것을 볼 수 있다. 넘겨받은 prop라는 키가 target에 있는 지를 검사하고 있다면 그 값을 없다면 0을 리턴하는 예제다.

원래 객체에 없는 Property에 접근 시에는 undefined를 리턴하게 되지만 Get Trap를 활용하여 0을 리턴하게 커스텀할 수 있다.

아래와 같이 구현하면 숫자뿐만 아니라 문자열에 대한 처리도 안전하게 가능하다.

```javascript
const person = {
  name: "John",
  introduce: "I'm John",
};

const personProxy = new Proxy(person, {
  get(target, prop) {
    if (prop in target) {
      return target[prop];
    } else {
      return prop;
    }
  },
});

console.log(personProxy.name); // John
console.log(personProxy.age); // age -> 프로퍼티가 없어서 키를 그대로 반환
console.log(personProxy.introduce); // I'm John
```

### Set Trap

Set Trap은 프로퍼티를 쓸 때 작업을 가로챌 수 있습니다. 예를 들면 숫자로 구성된 배열을 구성할 때가 있습니다.

```javascript
const nums = [];
```
