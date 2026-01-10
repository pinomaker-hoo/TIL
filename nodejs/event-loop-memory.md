# Node.js 이벤트 루프와 메모리 관리

## 목차
1. [이벤트 루프 개요](#1-이벤트-루프-개요)
2. [이벤트 루프의 6개 페이즈](#2-이벤트-루프의-6개-페이즈)
3. [이벤트 루프와 메모리 관계](#3-이벤트-루프와-메모리-관계)
4. [이벤트 루프 블로킹과 메모리](#4-이벤트-루프-블로킹과-메모리)
5. [비동기 패턴별 메모리 영향](#5-비동기-패턴별-메모리-영향)
6. [타이머와 메모리 누수](#6-타이머와-메모리-누수)
7. [EventEmitter와 메모리](#7-eventemitter와-메모리)
8. [실전 패턴](#8-실전-패턴-메모리-안전한-이벤트-루프-사용)
9. [디버깅 도구](#9-디버깅-도구)

---

## 1. 이벤트 루프 개요

### Node.js의 핵심: 싱글 스레드 + 이벤트 루프

Node.js는 **싱글 스레드 이벤트 루프** 기반의 비동기 I/O 모델을 사용합니다. 이는 하나의 메인 스레드만으로 수천 개의 동시 연결을 처리할 수 있게 하는 핵심 메커니즘입니다.

#### 왜 싱글 스레드인가?

**장점:**
- **메모리 효율성**: 스레드 생성 비용 없음 (스레드당 ~1MB 메모리)
- **단순성**: 동기화, 락, 데드락 걱정 없음
- **높은 처리량**: I/O 대기 시간 동안 다른 작업 처리 가능

**단점:**
- CPU 집약적 작업에는 부적합 (다른 요청 블로킹)
- 하나의 에러가 전체 프로세스 중단 가능

```
┌───────────────────────────┐
│   JavaScript Code         │  ← 우리가 작성하는 코드 (싱글 스레드)
│   (Single Thread)         │     모든 콜백, 이벤트 핸들러는 여기서 실행
└─────────────┬─────────────┘
              │
              ▼
┌───────────────────────────┐
│   Event Loop              │  ← libuv가 관리하는 이벤트 루프
│   (libuv - C library)     │     비동기 작업 조율 및 콜백 실행
├───────────────────────────┤
│  ┌─────────────────────┐  │
│  │   Call Stack        │  │  ← 현재 실행 중인 함수들
│  └─────────────────────┘  │
│  ┌─────────────────────┐  │
│  │   Event Queue       │  │  ← 실행 대기 중인 콜백들
│  └─────────────────────┘  │
└───────────────────────────┘
              │
              ▼
┌───────────────────────────┐
│   Thread Pool (libuv)     │  ← 백그라운드 워커 스레드들
│   - File I/O              │     (기본 4개, 최대 128개)
│   - DNS lookup            │     여기서 실제 I/O 작업 수행
│   - Compression           │
│   - Crypto (일부)         │
└───────────────────────────┘
```

### 동작 원리 예시

```javascript
const fs = require('fs');

console.log('1. 동기 코드 시작');

// 비동기 파일 읽기
fs.readFile('file.txt', (err, data) => {
  console.log('3. 파일 읽기 완료 (콜백 실행)');
});

console.log('2. 동기 코드 끝');

/*
실행 순서:
1. "1. 동기 코드 시작" 출력
2. fs.readFile() 호출
   → Thread Pool에 작업 요청
   → 즉시 다음 코드로 이동 (Non-blocking!)
3. "2. 동기 코드 끝" 출력
4. Thread Pool에서 파일 읽기 완료
   → 콜백이 Event Queue에 추가됨
5. Event Loop가 콜백을 Call Stack으로 가져옴
6. "3. 파일 읽기 완료" 출력

결과:
1. 동기 코드 시작
2. 동기 코드 끝
3. 파일 읽기 완료 (콜백 실행)
*/
```

---

## 2. 이벤트 루프의 6개 페이즈

이벤트 루프는 **6개의 페이즈를 순환**하며 각 페이즈는 특정 유형의 콜백을 처리합니다.

```
   ┌───────────────────────────┐
┌─>│  timers                   │  Phase 1: setTimeout, setInterval
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │  pending callbacks        │  Phase 2: 지연된 I/O 콜백
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
│  │  idle, prepare            │  Phase 3: 내부용 (개발자 접근 불가)
│  └─────────────┬─────────────┘      ┌───────────────┐
│  ┌─────────────┴─────────────┐      │   incoming:   │
│  │  poll                     │<─────┤  connections, │  Phase 4: 가장 중요!
│  └─────────────┬─────────────┘      │   data, etc.  │           I/O 처리
│  ┌─────────────┴─────────────┐      └───────────────┘
│  │  check                    │  Phase 5: setImmediate
│  └─────────────┬─────────────┘
│  ┌─────────────┴─────────────┐
└──┤  close callbacks          │  Phase 6: socket.on('close')
   └───────────────────────────┘
```

### 2.1 각 페이즈 상세 설명

#### Phase 1: Timers (타이머 페이즈)

**목적**: `setTimeout`과 `setInterval`의 콜백 실행

```javascript
// setTimeout/setInterval 콜백 실행
setTimeout(() => {
  console.log('Timer callback executed');
}, 100);

/*
동작 원리:
1. setTimeout 호출 시:
   - 타이머 객체가 힙(Heap)에 생성됨
   - 콜백 함수가 메모리에 유지됨
   - 만료 시간 기록 (현재시간 + 100ms)

2. Timers 페이즈에서:
   - 현재 시간을 체크
   - 만료된 타이머의 콜백을 실행
   - 타이머 객체는 실행 후 GC 대상이 됨

메모리 관점:
- 타이머 객체: 힙에 할당 (~100 bytes)
- 콜백 함수: 힙에 할당
- 클로저 변수: 콜백이 참조하면 메모리 유지
- 타이머 실행 또는 clear 전까지 GC 불가!
*/

// 예시: 메모리에 미치는 영향
function scheduledTask() {
  const largeData = new Array(100000).fill('data');  // ~800KB

  setTimeout(() => {
    console.log('Processing:', largeData.length);
    // 타이머가 실행되기 전까지 largeData는 메모리에 유지
  }, 5000);

  // 5초 동안 largeData는 GC 불가능
}
```

**중요 특징:**
- **정확한 시간 보장 안됨**: 100ms 설정해도 100ms 정확히 실행되지 않음
- 이벤트 루프가 다른 작업 중이면 지연될 수 있음

```javascript
// 타이머 지연 예시
setTimeout(() => console.log('Should run at 100ms'), 100);

// 무거운 동기 작업 (200ms 소요)
const start = Date.now();
while (Date.now() - start < 200) {
  // CPU 집약적 작업
}

// 결과: 타이머는 100ms가 아니라 200ms 이후에 실행됨!
```

#### Phase 2: Pending Callbacks (보류 중인 콜백)

**목적**: 이전 이벤트 루프 사이클에서 지연된 I/O 콜백 처리

```javascript
// 주로 시스템 수준의 콜백 처리
// 예: TCP 에러, ECONNREFUSED 등

// 개발자가 직접 다루지 않는 내부 페이즈
// 대부분 TCP/UDP 소켓 에러 처리
```

**메모리 영향:**
- 일반적으로 작은 콜백들이 처리됨
- 대부분 빠르게 실행되고 GC됨

#### Phase 3: Idle, Prepare (유휴, 준비)

**목적**: Node.js 내부 작업용

```javascript
// 개발자가 직접 사용하지 않음
// libuv가 내부적으로 사용하는 페이즈
```

#### Phase 4: Poll (폴 페이즈) - 가장 중요!

**목적**: I/O 이벤트 처리 및 대기

이 페이즈는 이벤트 루프의 **핵심**입니다. 대부분의 콜백이 여기서 실행됩니다.

```javascript
const fs = require('fs');
const net = require('net');

// Poll 페이즈에서 처리되는 작업들

// 1. 파일 I/O
fs.readFile('file.txt', (err, data) => {
  console.log('File read - executed in Poll phase');
  // Thread Pool에서 작업 완료 → 여기로 콜백 전달
});

// 2. 네트워크 I/O
const server = net.createServer((socket) => {
  socket.on('data', (data) => {
    console.log('Data received - executed in Poll phase');
    // 네트워크 데이터 수신 → 여기서 처리
  });
});

server.listen(3000);

// 3. HTTP 요청
const http = require('http');
http.get('http://example.com', (res) => {
  console.log('HTTP response - executed in Poll phase');
});
```

**Poll 페이즈 동작 흐름:**

```javascript
/*
Poll 페이즈 진입 시:

1. 실행할 콜백이 Poll Queue에 있는가?
   ├─ YES → 모든 콜백을 동기적으로 실행
   │        (또는 시스템 한계에 도달할 때까지)
   └─ NO → 2번으로

2. Poll Queue가 비어있을 때:

   A. setImmediate 콜백이 있는가?
      ├─ YES → Poll 종료, Check 페이즈로 이동
      └─ NO → B로

   B. 타이머가 만료되었는가?
      ├─ YES → Poll 종료, Timers 페이즈로 이동
      └─ NO → C로

   C. Poll 페이즈에서 대기 (블로킹)
      - I/O 이벤트를 기다림
      - 새로운 연결, 데이터 수신 등
      - 타이머 만료되면 깨어남
*/

// 실제 예시
console.log('1: Start');

setTimeout(() => console.log('2: Timer'), 0);

setImmediate(() => console.log('3: Immediate'));

fs.readFile(__filename, () => {
  console.log('4: File read');

  setTimeout(() => console.log('5: Timer in callback'), 0);
  setImmediate(() => console.log('6: Immediate in callback'));
});

console.log('7: End');

/*
실행 순서:
1: Start
7: End
2: Timer (또는 3이 먼저 나올 수도 있음 - 상황에 따라 다름)
3: Immediate
4: File read
6: Immediate in callback  ← I/O 사이클 내에서는 항상 setImmediate가 먼저!
5: Timer in callback
*/
```

**메모리 관점:**

```javascript
// Poll 페이즈의 메모리 영향
const fs = require('fs');

// ❌ 나쁜 예: 동시에 많은 파일 읽기
function readManyFiles(files) {
  files.forEach(file => {
    fs.readFile(file, (err, data) => {
      // 모든 파일 데이터가 동시에 메모리에 로드됨!
      processData(data);
    });
  });
}

readManyFiles(Array(1000).fill('large-file.txt'));
// → 1000개 파일이 동시에 메모리에! 💥

// ✅ 좋은 예: 순차 처리 또는 동시성 제한
async function readManyFilesSequentially(files) {
  for (const file of files) {
    const data = await fs.promises.readFile(file);
    await processData(data);
    // 한 번에 하나씩, 처리 후 GC 가능
  }
}
```

#### Phase 5: Check (체크 페이즈)

**목적**: `setImmediate` 콜백 실행

```javascript
// setImmediate 콜백 실행
setImmediate(() => {
  console.log('Immediate callback');
});

/*
setImmediate의 특징:
- Poll 페이즈 직후에 실행됨
- I/O 사이클 내에서는 setTimeout(fn, 0)보다 먼저 실행
*/

// setImmediate vs setTimeout(fn, 0)
setTimeout(() => console.log('timeout'), 0);
setImmediate(() => console.log('immediate'));

/*
실행 순서는 **상황에 따라 다름**:
- 메인 모듈에서 실행: 순서 보장 안됨 (시스템에 따라 다름)
- I/O 사이클 내에서 실행: setImmediate가 항상 먼저!
*/

// I/O 사이클 내에서는 순서 보장
const fs = require('fs');

fs.readFile(__filename, () => {
  setTimeout(() => console.log('timeout'), 0);
  setImmediate(() => console.log('immediate'));
});

/*
항상 출력:
immediate
timeout

이유:
1. fs.readFile 콜백은 Poll 페이즈에서 실행
2. Poll 페이즈 다음은 Check 페이즈
3. setImmediate 먼저 실행
4. 그 다음 루프에서 Timers 페이즈의 setTimeout 실행
*/
```

**왜 setImmediate를 사용하는가?**

```javascript
// 재귀적 I/O 작업 시 사용
function processNextChunk(chunks, index = 0) {
  if (index >= chunks.length) return;

  processChunk(chunks[index]);

  // ✅ setImmediate 사용: 다른 I/O도 처리 가능
  setImmediate(() => {
    processNextChunk(chunks, index + 1);
  });
}

// ❌ 나쁜 예: 동기적 재귀
function processNextChunkBad(chunks, index = 0) {
  if (index >= chunks.length) return;

  processChunk(chunks[index]);
  processNextChunkBad(chunks, index + 1);
  // 모든 청크를 한 번에 처리 → 다른 요청 블로킹!
}
```

#### Phase 6: Close Callbacks (종료 콜백)

**목적**: `close` 이벤트 콜백 실행

```javascript
const net = require('net');
const server = net.createServer();

server.on('close', () => {
  console.log('Server closed');
  // close callbacks 페이즈에서 실행
});

server.listen(3000);
server.close();

/*
Close 콜백 예시:
- socket.on('close')
- process.on('exit')
- stream.on('close')

메모리 정리:
- 리소스 정리하기 좋은 시점
- 이벤트 리스너 제거
- 메모리 해제
*/

// 실전 예시: 리소스 정리
class DatabaseConnection {
  constructor() {
    this.connection = createConnection();
    this.cache = new Map();

    this.connection.on('close', () => {
      // 연결 종료 시 정리
      this.cache.clear();
      this.cache = null;
      console.log('Resources cleaned up');
    });
  }

  close() {
    this.connection.close();
  }
}
```

### 2.2 Microtask Queue (마이크로태스크 큐) - 매우 중요!

**Microtask는 각 페이즈 사이에 실행됩니다!**

```javascript
// Microtasks의 두 가지 종류:
// 1. process.nextTick() - 가장 높은 우선순위
// 2. Promise callbacks - 그 다음 우선순위

console.log('1: Script start');

setTimeout(() => console.log('2: setTimeout'), 0);

Promise.resolve()
  .then(() => console.log('3: Promise 1'))
  .then(() => console.log('4: Promise 2'));

process.nextTick(() => console.log('5: nextTick 1'));
process.nextTick(() => console.log('6: nextTick 2'));

setImmediate(() => console.log('7: setImmediate'));

console.log('8: Script end');

/*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
실행 순서 및 이유:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1: Script start        ← 동기 코드
8: Script end          ← 동기 코드

───── 동기 코드 끝, Microtask 큐 처리 ─────

5: nextTick 1          ← nextTick 큐가 가장 먼저!
6: nextTick 2          ← nextTick 큐 비우기

3: Promise 1           ← 그 다음 Promise 큐
4: Promise 2           ← Promise 큐 비우기

───── Microtask 끝, 이벤트 루프 페이즈 시작 ─────

2: setTimeout          ← Timers 페이즈
7: setImmediate        ← Check 페이즈

우선순위:
nextTick 큐 > Promise 큐 > 페이즈 콜백
*/
```

#### Microtask 실행 시점

```javascript
/*
각 페이즈 사이마다 Microtask 큐를 확인하고 비웁니다:

Timers 페이즈
    ↓
[nextTick 큐 체크]
[Promise 큐 체크]
    ↓
Pending 페이즈
    ↓
[nextTick 큐 체크]
[Promise 큐 체크]
    ↓
Poll 페이즈
    ↓
[nextTick 큐 체크]
[Promise 큐 체크]
    ↓
Check 페이즈
    ↓
[nextTick 큐 체크]
[Promise 큐 체크]
    ↓
Close 페이즈
*/

// 실제 예시
setImmediate(() => {
  console.log('1: setImmediate');

  process.nextTick(() => {
    console.log('2: nextTick in setImmediate');
  });
});

setImmediate(() => {
  console.log('3: setImmediate 2');
});

/*
출력:
1: setImmediate
2: nextTick in setImmediate  ← Check 페이즈 콜백 사이에 Microtask 실행!
3: setImmediate 2

이유:
1. 첫 번째 setImmediate 실행
2. nextTick이 큐에 추가됨
3. Check 페이즈의 다음 콜백 실행 전에 Microtask 큐 체크
4. nextTick 실행
5. 두 번째 setImmediate 실행
*/
```

#### process.nextTick의 위험성

```javascript
// ⚠️ 경고: nextTick 재귀는 이벤트 루프를 정지시킬 수 있음!

let count = 0;

function recursiveNextTick() {
  count++;
  if (count < 1000000) {
    process.nextTick(recursiveNextTick);
  }
}

recursiveNextTick();

/*
문제점:
1. nextTick 큐가 계속 채워짐
2. 다음 페이즈로 넘어가지 못함
3. I/O 처리 불가능
4. 애플리케이션 정지!

메모리 영향:
- 100만 개의 콜백이 큐에 쌓임
- 각 콜백 객체 ~100 bytes
- 총 ~100MB 메모리 사용
- 이벤트 루프 블로킹으로 다른 요청 처리 불가
*/

// ✅ 올바른 방법: setImmediate 사용
function recursiveImmediate() {
  count++;
  if (count < 1000000) {
    setImmediate(recursiveImmediate);
  }
}

/*
setImmediate의 장점:
- 각 이벤트 루프 사이클마다 한 번만 실행
- 다른 페이즈도 정상 처리
- I/O 작업도 함께 처리됨
*/
```

---

## 3. 이벤트 루프와 메모리 관계

### 3.1 콜백 큐와 메모리

이벤트 루프의 각 큐는 **메모리에 콜백 함수들을 저장**합니다. 콜백이 많아지면 메모리 사용량도 증가합니다.

```javascript
// ❌ 나쁜 예: 콜백 큐에 무거운 객체 누적
const heavyData = [];  // 전역 배열

setInterval(() => {
  const data = new Array(100000).fill('data');  // ~800KB
  heavyData.push(data);  // 계속 누적!

  processData(data);
}, 100);

/*
메모리 문제:
1. setInterval이 100ms마다 실행됨
   → 초당 10번 × 800KB = 8MB/초 증가

2. heavyData가 전역 변수
   → GC 불가능
   → 1분 후 480MB 사용!

3. setInterval 콜백 자체도 메모리 점유
   → 콜백이 heavyData를 참조
   → heavyData의 모든 요소가 메모리에 유지

시간대별 메모리 사용:
10초 후: 80MB
30초 후: 240MB
1분 후: 480MB
5분 후: 2.4GB → 💥 크래시!
*/

// ✅ 좋은 예: 크기 제한
const MAX_SIZE = 100;
const dataQueue = [];

setInterval(() => {
  const data = new Array(100000).fill('data');

  // FIFO 방식으로 오래된 데이터 제거
  if (dataQueue.length >= MAX_SIZE) {
    const removed = dataQueue.shift();
    // removed는 이제 GC 대상
  }

  dataQueue.push(data);
  processData(data);
}, 100);

/*
메모리 사용:
- 최대 100개 × 800KB = 80MB로 제한
- 더 이상 증가하지 않음
- 안정적인 메모리 사용 패턴
*/
```

#### 큐 크기 모니터링

```javascript
// 큐 크기 추적 및 경고
class QueueMonitor {
  constructor(maxSize = 1000) {
    this.queue = [];
    this.maxSize = maxSize;
    this.droppedCount = 0;
  }

  enqueue(item) {
    if (this.queue.length >= this.maxSize) {
      console.warn(`⚠️ Queue full! Dropping oldest item`);
      this.queue.shift();
      this.droppedCount++;
    }

    this.queue.push(item);
  }

  dequeue() {
    return this.queue.shift();
  }

  getStats() {
    return {
      currentSize: this.queue.length,
      maxSize: this.maxSize,
      droppedCount: this.droppedCount,
      utilizationPercent: (this.queue.length / this.maxSize * 100).toFixed(2)
    };
  }
}

// 사용
const taskQueue = new QueueMonitor(1000);

setInterval(() => {
  taskQueue.enqueue({ data: 'task' });

  // 큐 크기 체크
  const stats = taskQueue.getStats();
  if (stats.currentSize > stats.maxSize * 0.8) {
    console.warn('Queue 80% full:', stats);
  }
}, 10);
```

### 3.2 nextTick과 메모리 폭탄

`process.nextTick`은 매우 강력하지만 **잘못 사용하면 메모리 폭탄**이 될 수 있습니다.

```javascript
// ❌ 매우 위험한 패턴: nextTick 재귀
let count = 0;

function recursiveNextTick() {
  count++;
  console.log('Count:', count);

  if (count < 1000000) {
    process.nextTick(recursiveNextTick);
  }
}

recursiveNextTick();

/*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
문제점 분석:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. nextTick 큐 무한정 증가:
   - 매 호출마다 새로운 콜백이 nextTick 큐에 추가
   - nextTick 큐는 완전히 비워질 때까지 다음 페이즈로 이동 안함
   - 100만 개의 콜백이 모두 큐에 쌓임

2. 이벤트 루프 블로킹:
   - Poll 페이즈로 이동 불가
   - I/O 이벤트 처리 불가
   - 다른 요청 완전 정지

3. 메모리 사용량 급증:
   - 각 콜백: ~100 bytes (함수 객체 + 클로저)
   - 100만 개 × 100 bytes = 100MB
   - 실제로는 더 많이 사용 (V8 오버헤드 포함)

4. CPU 100% 사용:
   - 동기적으로 100만 번 함수 호출
   - 다른 작업 처리 불가

결과: 애플리케이션 정지, 메모리 부족, 타임아웃 에러 발생
*/

// ✅ 올바른 방법: setImmediate 사용
function recursiveImmediate() {
  count++;
  console.log('Count:', count);

  if (count < 1000000) {
    setImmediate(recursiveImmediate);
  }
}

recursiveImmediate();

/*
setImmediate의 장점:
1. 각 이벤트 루프 사이클마다 한 번만 실행
2. 다른 페이즈도 정상 처리
3. I/O 작업 동시 처리 가능
4. 메모리 사용량 일정 (큐에 1~2개만 유지)

실행 흐름:
Check 페이즈 → recursiveImmediate 실행 → 다음 큐에 추가
  ↓
Timers 페이즈 (다른 타이머 처리 가능)
  ↓
Poll 페이즈 (I/O 처리 가능)
  ↓
Check 페이즈 → recursiveImmediate 실행 → ...

총 실행 시간은 더 길지만, 애플리케이션은 반응형 유지!
*/
```

#### 실전 사례: 대용량 데이터 처리

```javascript
// 시나리오: 100만 개 레코드 처리

// ❌ 나쁜 예: 동기 처리
function processAllRecordsBad(records) {
  records.forEach(record => {
    processRecord(record);  // CPU 집약적 작업
  });
  // 100만 개를 한 번에 처리 → 몇 분 동안 블로킹!
}

// ❌ 나쁜 예: nextTick 사용
function processAllRecordsNextTick(records, index = 0) {
  if (index >= records.length) return;

  processRecord(records[index]);

  process.nextTick(() => {
    processAllRecordsNextTick(records, index + 1);
  });
  // nextTick 큐에 100만 개 쌓임 → 메모리 폭탄!
}

// ✅ 좋은 예: setImmediate로 배치 처리
function processAllRecordsGood(records, index = 0, batchSize = 1000) {
  if (index >= records.length) {
    console.log('All records processed');
    return;
  }

  // 배치 단위로 처리
  const end = Math.min(index + batchSize, records.length);
  for (let i = index; i < end; i++) {
    processRecord(records[i]);
  }

  console.log(`Processed ${end}/${records.length}`);

  // 다음 배치는 다음 이벤트 루프에서
  setImmediate(() => {
    processAllRecordsGood(records, end, batchSize);
  });
}

/*
성능 비교:

동기 처리:
- 총 시간: 30초
- 블로킹: 30초 (다른 요청 처리 불가)
- 메모리: 안정

nextTick:
- 총 시간: 35초
- 블로킹: 35초 (완전 정지)
- 메모리: 급증 후 크래시 가능

setImmediate (배치 1000):
- 총 시간: 35초
- 블로킹: 0초 (다른 요청 정상 처리)
- 메모리: 안정
- 사용자 경험: 훨씬 좋음!
*/
```

### 3.3 Promise 체인과 메모리

Promise도 잘못 사용하면 메모리 누수가 발생할 수 있습니다.

```javascript
// ❌ 나쁜 예: Promise 체인 메모리 누수
let promiseChain = Promise.resolve();

function addToChain(data) {
  promiseChain = promiseChain.then(() => {
    return processData(data);
  });
}

// 10,000번 호출
for (let i = 0; i < 10000; i++) {
  addToChain({ id: i, data: 'sample' });
}

/*
문제점:
1. Promise 체인이 계속 길어짐:
   Promise1.then(Promise2).then(Promise3).then...Promise10000

2. 이전 Promise들이 메모리에 유지:
   - 각 Promise: ~200 bytes
   - 10,000개 × 200 bytes = 2MB
   - 실제로는 클로저 변수 포함하면 훨씬 큼

3. GC 불가능:
   - promiseChain 변수가 계속 참조
   - 전체 체인이 메모리에 유지

시간이 지날수록:
100,000개: 20MB
1,000,000개: 200MB
→ 메모리 부족!
*/

// ✅ 좋은 예 1: 독립적인 Promise 사용
async function processBatch(items) {
  for (const item of items) {
    await processData(item);
    // 각 Promise는 완료 후 GC 가능
  }
}

// ✅ 좋은 예 2: 동시성 제한
const pLimit = require('p-limit');
const limit = pLimit(10);  // 최대 10개 동시 실행

async function processBatchConcurrent(items) {
  const promises = items.map(item =>
    limit(() => processData(item))
  );

  await Promise.all(promises);
}

/*
메모리 사용 비교:

나쁜 예 (체인):
- 10,000개: 전부 메모리에 유지 → ~20MB

좋은 예 1 (순차):
- 항상 1개만 메모리 점유 → ~200 bytes

좋은 예 2 (동시성 제한):
- 최대 10개만 메모리 점유 → ~2KB
- 처리 속도는 훨씬 빠름!
*/
```

#### Promise와 Microtask 메모리

```javascript
// Promise 콜백은 Microtask 큐에 추가됨

console.log('Start');

Promise.resolve().then(() => {
  console.log('Promise 1');

  // 또 다른 Promise 생성
  Promise.resolve().then(() => {
    console.log('Promise 2 (nested)');
  });
});

console.log('End');

/*
실행 순서:
Start
End
Promise 1
Promise 2 (nested)

메모리 동작:
1. 첫 Promise 콜백이 Microtask 큐에 추가
2. 동기 코드 완료
3. Microtask 큐 처리: Promise 1 실행
4. 중첩된 Promise 콜백이 Microtask 큐에 추가
5. Microtask 큐 처리: Promise 2 실행
6. Microtask 큐 비움
7. 다음 페이즈로 이동

각 Promise 객체는 실행 후 즉시 GC 대상이 됨
*/
```

---

## 4. 이벤트 루프 블로킹과 메모리

### 4.1 CPU 집약적 작업 블로킹

CPU 집약적 작업은 **이벤트 루프를 블로킹**하여 다른 요청을 처리하지 못하게 합니다.

```javascript
// ❌ 나쁜 예: 이벤트 루프 블로킹
function heavyComputation() {
  const result = [];

  // 1000만 번 반복 → 수 초 소요
  for (let i = 0; i < 10000000; i++) {
    result.push(Math.sqrt(i));
  }

  return result;
}

// Express 서버에서
app.get('/compute', (req, res) => {
  const result = heavyComputation();  // 3초 블로킹!

  // 문제:
  // - 이 요청 처리 중 다른 모든 요청이 대기
  // - 사용자는 3초 동안 아무 응답도 받지 못함
  // - 서버가 "멈춘 것처럼" 보임

  res.json({ result });
});

/*
시나리오:
- 사용자 A: /compute 요청 (3초 블로킹 시작)
- 사용자 B: /api/users 요청 (1초 대기 중...)
- 사용자 C: /api/posts 요청 (2초 대기 중...)
- 3초 후 사용자 A 응답
- 그제서야 B, C 요청 처리 시작

결과: 모든 사용자가 나쁜 경험
*/

// ✅ 좋은 예 1: 작업 분할 (setImmediate 사용)
function heavyComputationAsync(callback) {
  const result = [];
  let i = 0;
  const chunkSize = 10000;  // 한 번에 10,000개씩

  function processChunk() {
    const end = Math.min(i + chunkSize, 10000000);

    // 청크 처리
    for (; i < end; i++) {
      result.push(Math.sqrt(i));
    }

    if (i < 10000000) {
      // 다음 청크는 다음 이벤트 루프에서
      setImmediate(processChunk);
    } else {
      // 완료
      callback(result);
    }
  }

  processChunk();
}

app.get('/compute-async', (req, res) => {
  heavyComputationAsync((result) => {
    res.json({ result });
  });

  // 장점:
  // - 총 시간은 비슷 (3~3.5초)
  // - 다른 요청도 중간중간 처리됨!
  // - 서버 응답성 유지
});

/*
실행 흐름:
0.0초: A의 /compute-async 시작, 청크 1 처리
0.1초: B의 /api/users 처리 (빠르게 응답)
0.1초: A의 청크 2 처리
0.2초: C의 /api/posts 처리 (빠르게 응답)
0.2초: A의 청크 3 처리
...
3.5초: A의 결과 응답

모든 사용자가 빠른 응답 경험!
*/

// ✅ 좋은 예 2: Worker Threads 사용
const { Worker } = require('worker_threads');

function heavyComputationWorker() {
  return new Promise((resolve, reject) => {
    const worker = new Worker(`
      const { parentPort } = require('worker_threads');

      const result = [];
      for (let i = 0; i < 10000000; i++) {
        result.push(Math.sqrt(i));
      }

      parentPort.postMessage(result);
    `, { eval: true });

    worker.on('message', resolve);
    worker.on('error', reject);
    worker.on('exit', (code) => {
      if (code !== 0) {
        reject(new Error(`Worker stopped with exit code ${code}`));
      }
    });
  });
}

app.get('/compute-worker', async (req, res) => {
  try {
    const result = await heavyComputationWorker();
    res.json({ result });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }

  // 장점:
  // - 별도 스레드에서 실행 → 메인 스레드 블로킹 없음!
  // - 다른 요청 완전히 독립적으로 처리
  // - CPU 코어를 효율적으로 활용
});

/*
Worker Threads 동작:
┌──────────────────────────┐
│   Main Thread            │  ← 이벤트 루프, 요청 처리
│   (Event Loop)           │     완전히 블로킹 없음!
└────────────┬─────────────┘
             │
             ├─> Worker Thread 1  ← heavyComputation 실행
             │
             ├─> Worker Thread 2  ← 다른 작업 가능
             │
             └─> Worker Thread 3
*/
```

#### 블로킹 감지

```javascript
// 블로킹 감지 유틸리티
function detectBlocking(thresholdMs = 100) {
  let lastCheck = Date.now();

  setInterval(() => {
    const now = Date.now();
    const delay = now - lastCheck - 1000;

    if (delay > thresholdMs) {
      console.warn(`⚠️ Event loop blocked for ${delay}ms!`);

      // 스택 트레이스 캡처 (실제로는 더 정교한 방법 필요)
      console.trace('Potential blocking code');
    }

    lastCheck = now;
  }, 1000);
}

detectBlocking(100);

// 사용 시나리오
app.get('/api/data', (req, res) => {
  // 이 핸들러가 100ms 이상 걸리면 경고 발생
  const data = heavyOperation();
  res.json(data);
});
```

### 4.2 이벤트 루프 Lag 모니터링

**이벤트 루프 Lag**는 이벤트 루프가 얼마나 지연되고 있는지를 측정하는 지표입니다.

```javascript
class EventLoopMonitor {
  constructor(threshold = 100) {
    this.threshold = threshold;  // ms
    this.lastCheck = Date.now();
    this.lagHistory = [];
  }

  start(interval = 1000) {
    this.intervalId = setInterval(() => {
      const now = Date.now();

      // 예상 시간과 실제 시간의 차이 = Lag
      const expectedDelay = interval;
      const actualDelay = now - this.lastCheck;
      const lag = actualDelay - expectedDelay;

      this.lagHistory.push(lag);
      if (this.lagHistory.length > 60) {
        this.lagHistory.shift();  // 최근 60개만 유지
      }

      if (lag > this.threshold) {
        console.warn(`⚠️ Event loop lag detected: ${lag}ms`);

        // 메모리 상태도 함께 체크
        const mem = process.memoryUsage();
        console.warn(`Memory usage:`);
        console.warn(`  Heap used: ${Math.round(mem.heapUsed / 1024 / 1024)}MB`);
        console.warn(`  RSS: ${Math.round(mem.rss / 1024 / 1024)}MB`);

        // 평균 Lag 계산
        const avgLag = this.lagHistory.reduce((sum, l) => sum + l, 0) / this.lagHistory.length;
        console.warn(`  Average lag (last ${this.lagHistory.length}s): ${avgLag.toFixed(2)}ms`);
      }

      this.lastCheck = now;
    }, interval);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  }

  getStats() {
    if (this.lagHistory.length === 0) {
      return { avgLag: 0, maxLag: 0 };
    }

    const avgLag = this.lagHistory.reduce((sum, l) => sum + l, 0) / this.lagHistory.length;
    const maxLag = Math.max(...this.lagHistory);

    return {
      avgLag: avgLag.toFixed(2),
      maxLag,
      samples: this.lagHistory.length
    };
  }
}

// 사용 예
const monitor = new EventLoopMonitor(100);
monitor.start(1000);

// 상태 확인
setInterval(() => {
  const stats = monitor.getStats();
  console.log('Event Loop Stats:', stats);
}, 10000);

/*
정상 상태:
Event Loop Stats: { avgLag: '2.34', maxLag: 15, samples: 60 }

문제 상태:
⚠️ Event loop lag detected: 523ms
Memory usage:
  Heap used: 450MB
  RSS: 520MB
  Average lag (last 60s): 45.67ms

Event Loop Stats: { avgLag: '45.67', maxLag: 523, samples: 60 }
→ CPU 집약적 작업이나 메모리 압박 의심!
*/
```

---

계속해서 나머지 섹션들도 작성하겠습니다. 파일이 매우 커서 여기서 일단 저장하고, 이어서 작성하겠습니다.
