# Nodejs

## 개요

한 번에 끝내는 Node.js 웹 프로그래밍 초격차 패키지 Online를 듣고 정리한 내용 입니다.

<br />

## 목차

[1.Javascript의 이벤트 루프 모델](#1-javascript의-이벤트-루프-모델)
[2. Node.js의 핵심 개념](#2-nodejs의-핵심-개념)

<br />
<br />

# 1. Javascript의 이벤트 루프 모델

Javascript의 실행 모델은 event loop, call stack, callback queue 개념으로 이루어져 있다.

JS의 이벤트 루프 모델은 여러개의 쓰레드를 사용하고 있고, 우리가 작성한 JS 코드가 실행되는 스레드는 메인 스레드라고 한다.

Node.js 프로세스에서 메인 스레드는 하나이지만, file I/O, Network등을 하는 워커 스레드는 여러개일 수도 있다.

<br />

### Call Stack

<br />

![스크린샷 2023-07-01 오후 10 01 42](https://github.com/pinomaker-hoo/TIL/assets/56928532/95f8cbc2-57c3-4558-ae5c-eb8356b07775)

콜 스택은 지금 시점까지 불림 함수들의 스택을 의미한다. 스택은 FILO의 구조를 가진 자료구조이다. 콜 스택은 함수가 호출 될 때 하나 씩 쌓이고 리턴이 되면 하나 씩 빠진다.

이미지를 보면 f1()을 가장 먼저 호출되서 아래로 가게 되고, f2(), f3() 차례로 호출되어 콜 스택에 쌓이고 f3(), f2(), f1() 순으로 리턴되어 스택에서 빠지게된다.

<br />

![스크린샷 2023-07-01 오후 10 04 10](https://github.com/pinomaker-hoo/TIL/assets/56928532/cee69662-c014-4522-bcf9-e9bdccb371ce)

<br />

콜스택은 빈 상태로 시작되고 콜백 함수에 의하여 스택이 하나씩 쌓이고 다시 호출되어 콜스택이 다시 빈상태가 된다. 또한 이벤트 루프가 다음 콜백을 처리할려면 지금 처리하고 있는 콜백을 다 처리해야 가능하다.

### Callback Queue

<br />

![스크린샷 2023-07-01 오후 10 14 59](https://github.com/pinomaker-hoo/TIL/assets/56928532/a30c2af9-f235-41e8-a763-6a5178ff01b6)

콜백 큐는 아픙로 실행할 콜백(함수와 그 인자)를 쌓아두는 큐를 의미한다. 즉 위에서 설명한 콜 스택을 쌓는 거다.
큐는 LILO의 구조로 먼저 들어온 것이 가장 먼저 나가는 자료구조다. 콜백은 브라우저나 Node가 어떤 일이 발생하면 메인스레드에 이를 알려주기 위해 사용된다.

콜백 큐는 콜스택이 빈상태가 될 때까지 기다렸다가 빈 상태가 되면은 콜백큐에서 하나를 꺼낸다고 생각하면 된다.

```javascript
console.log("1");
setTimeout(() => {
  console.log("2");
});
console.log("3");
```

위의 코드의 출력 순서는 1, 3, 2다. setTimeout이 console.log("2")를 실행시키는 콜백을 가지고 있지만 아직 실행은 시키지 않은 상태이기에 1, 3, 2 순서로 출력된다.

```javascript
setInterval(() => {
  console.log("HELLO");
  while (true) {}
}, 1000);
```

위의 코드에서는 5초 동안 Hey를 출력하는 횟수는 단 1번이다. 콜 스택이 비어야 콜백큐에서 다음 이벤트를 실행시키는 데, while(true){}에서 콜스택이 끝나지 않아 비지 않기 때문이다.

이러한 것을 event loop를 block한다고 한다. 이벤트의 순환을 막는 것이다.

<br />

### non-blocking I/O & offloading

<br />

```javascript
fs.readFile(fileName, (err, data) => {});

someTask();
```

<br />

위의 코드를 보면 Node에게 파일 Read를 요청하면 워커 스레드에서 파일을 읽기 시작한다. 그러면 다음 동작은 어디가 될까? 바로 콜백을 실행시키지 않고 readFile()의 호출이 끝나면 바로 someTask()를 호출한다. 그 이유는 콜스택이 빌 때까지 처리를 해야하기 때문이다.

Node가 파일을 다 읽으면 콜백큐에 (err, data) => {}를 묶어서 집어넣고, 콜스택이 비게 되면 어느 순간 넣은 함수를 실행한다.

브라우저나 Node에서 Web API 혹은 Node API의 동작이 끝나면 callback queue에 등록하는 데, 동작이 진행할 동안 메인 스레드와 이벤트 루프는 영향을 받지 않고 계속 실행한다.

이러한 현상을 offloading이라고 하며, Node 서버의 메인 스레드가 하나지만 빠르게 동작할 수 있는 이유다.

<br />

![스크린샷 2023-07-01 오후 10 34 03](https://github.com/pinomaker-hoo/TIL/assets/56928532/0e805402-a231-467a-a6d3-f17a19420db4)

<br />

콜백큐에서 콜백을 꺼내고(없다면 기다림), 그 콜백의 처리가 끝날 때까지 실행하는 것을 반복한다. 하나의 콜백을 처리하는 것은 워커 스레드에 일을 맡기고 다시 JS에 알려줄 것이 있다면 콜백큐에 어떤 일을 해야하는 지 등록한다.

이게 Javascript의 Event Loop다.

<br />

# 2. Node.js의 핵심 개념

<br />

## (1) 파일 시스템, Module

Node.js의 파일 시스템은 모듈이다. 공식 문서에 따르면 하나의 파일들이 각각 모듈로 취급되며 이 모듈들을 내보내고 가져오는 것을 module.exports와 require()를 통하여 할 수 있다.

```javascript
// a.js
const animals = ["dog", "cat"];

module.exports = animals;

// b.js
console.log(require("./a.js")); // ["dog", "cat"]
```

Node.js모듈 시스템에는 commonJS와 ECMAScript 2가지가 존재하는 데 표준은 commonJS는 require()를 ECMAScript는 export, import 문법을 사용한다.

해당 차이점에 대해서는 나중에 학습하여 기록할 예정이다. 참고로 ECMAScript가 표준이지만 Node.js에서는 commonJS를 사용한다.(현재는 둘 다 사용가능) 또한 node.js에서 ECMAScript를 사용하기 위해서는 mjs 확장자를 사용한다.

```javascript
// a.js
const animals = ["dog", "cat"];
console.log("a.js loaded!"); // a.js loaded
module.exports = animals;

// b.js
const a = require("./a.js");
const b = require("./a.js");
const c = require("./a.js");

console.log(a, b, c); //  ["dog", "cat"],  ["dog", "cat"],  ["dog", "cat"]
```

위의 코드를 보면 a, b, c에 a.js 모듈을 호춣하여 저장을 하였는 데, 실제로는 호출이 한 번된다. require()를 3번 사용했지만 console.log("a.js loaded")가 1번 실행된다. 즉 파일 시스템은 한 번 호출된다.

```javascript
const http = require("http");
const a = require("./a.js");
```

node standard Library에 있는 모듈들은 절대 경로를 지정해 가져오지만 이 프로젝트 내의 다른 파일은 상대 경로를 지정해 가져온다.

하지만 내 프로젝트 내에 임의로 node_modules 폴더를 만들고 그 안에 파일을 넣으면 절대 경로로 가져올 수도 있다.

<br />

## (2) Buffer

<br />

Buffer는 고정된 길이의 Byte 시퀀스를 표현하는 데 사용하는 객체다. Javasript Unit8Array의 subclass다.

```javascript
// test
abcde;

// main.js
const fs = require("fs");

const result = fs.readFileSync("src/tes");
console.log(result); // <Buffer 61 62 63 64 65>
```

1byte는 8bit로, 0 ~ 255 사이읭 값을 가지게 된다.(0~2^8-1) 위에 코드에 나온 숫자들은 abcde를 아스키코드로 바꾼 값과 같다.

```javascript
// abcde의 아스키코드(10진수)를 이용하여 Buffer 생성
const buf = Buffer.from([97, 98, 99, 100, 101]);
const bufFromFile = fs.readFileSync("src/tes");

console.log(buf); // // <Buffer 61 62 63 64 65>
console.log(buf.compare(bufFromFile));
```
