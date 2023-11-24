## Closure

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
