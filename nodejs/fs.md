## FS Module

FS(File System) 모듈은 파일 처리에 관련된 작업을 하는 모듈이다.

fs 모듈의 메서드는 동기와 비동기로 나누어지는 데, Sync의 이름이 붙여진 메서드가 동기 방식을 사용한다.

### readFile

먼저 1개의 text 파일을 준비한다.

```
# sample.txt

Hello world, I am testing about FS Module
```

<br />

fs에서 제공하는 파일 읽기는 readFile(), readFileSync이 존재하며 각 비동기냐 동기냐 정도의 차이가 존재한다.

```javascript
const fs = require("fs");

fs.readFile("sample.txt", "utf-8", (err, data) => {
  console.log("비동기 : ", data);
});

const text = fs.readFileSync("sample.txt", "utf-8");
console.log("동기 : ", text);
```

<br />

2개의 메서드 모두 utf-8로 sample.txt를 읽는 코드지만 동작하는 방법이 다르다. readFile은 비동기이기에, 호출 후에 파일이 전부 읽히면 다시 call stack에 스택이 쌓여 콜백을 처리하는 데, readFileSync는 동기이기에, 처리되기까지 다른 작업을 하지 않는다.

아래는 위의 코드를 실행했을 때의 실행 결과인데, Javascript의 이벤트 루프의 영향으로 readFileSync의 결과물을 먼저 Log를 찍는 걸 확인할 수 있다.

```
동기 :  Hello world
비동기 :  Hello world
```

### writeFile

writeFile은 readFile과 반대로 읽는 것이 아닌 파일을 출력하는 메서드다.

```javascript
const fs = require("fs");

const word = "Hello world, I am testing fs module";

fs.writeFile("sample.txt", word, "utf-8", (err) => {
  console.log("비동기 파일 생성");
});

fs.writeFileSync("sample2.txt", word, "utf-8");

console.log("동기 파일 생성");
```

<br />

해당 코드를 실행하면 위와 마찬가지로 동기 파일 생성이 먼저 로그에 찍히게 되고 파일이 생성된 것을 확인할 수 있다.

### 예외처리

동기와 비동기 메서드는 각 예외처리를 하는 방법이 다르다.

비동기 메서드의 경우에는 콜백 함수 안에 넘어오는 err 파라메터를 이용하여 if문으로 분기처리하면 된다.

```javascript
const fs = require("fs");

fs.readFile("sample.txt", "utf-8", (err, data) => {
  if (err) {
    console.log(err);
  }
  console.log("비동기 : ", data);
});
```

<br />

그리고 동기 메서드는 trycatch를 이용하여 예외처리를 해주면 된다.

```javascript
const fs = require("fs");

try {
  const text = fs.readFileSync("sample.txt", "utf-8");
  console.log("동기 : ", text);
} catch (err) {
  console.log(err);
}
```

<br />

### Promise 처리

FS Module도 Promise를 이용하여 처리가 가능하다.

```javascript
const fs = require("fs");
const fsPromise = fs.promises;

fsPromise
  .readFile("./sample.txt")
  .then((res) => {
    console.log(res.toString());
  })
  .catch((err) => {
    console.log(err);
  });
```
