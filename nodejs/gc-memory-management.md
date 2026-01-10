# Node.js GC와 메모리 관리

## 목차
1. [V8 엔진과 메모리 구조](#1-v8-엔진과-메모리-구조)
2. [Garbage Collection 알고리즘](#2-garbage-collection-알고리즘)
3. [메모리 누수 패턴과 해결법](#3-메모리-누수-패턴과-해결법)
4. [메모리 모니터링](#4-메모리-모니터링)
5. [V8 플래그를 통한 메모리 최적화](#5-v8-플래그를-통한-메모리-최적화)
6. [메모리 효율적인 코딩 패턴](#6-메모리-효율적인-코딩-패턴)
7. [실전 메모리 디버깅 워크플로우](#7-실전-메모리-디버깅-워크플로우)

---

## 1. V8 엔진과 메모리 구조

### 개요

Node.js는 구글에서 개발한 **V8 JavaScript 엔진**을 사용합니다. V8 엔진은 JavaScript 코드를 실행하고 메모리를 관리하는 핵심 컴포넌트입니다. V8은 **세대별 가비지 컬렉션(Generational Garbage Collection)** 전략을 사용하여 효율적으로 메모리를 관리합니다.

### 메모리 영역 구조

```
┌─────────────────────────────┐
│     Resident Set (RSS)      │  ← 프로세스가 실제로 점유하는 물리 메모리
├─────────────────────────────┤
│                             │
│  ┌─────────────────────┐   │
│  │   Heap Memory       │   │  ← JavaScript 객체가 저장되는 동적 메모리
│  ├─────────────────────┤   │
│  │   New Space         │   │  ← 젊은 세대 (Young Generation)
│  │   - Semi-space 0    │   │     새로 생성된 객체들이 위치
│  │   - Semi-space 1    │   │
│  ├─────────────────────┤   │
│  │   Old Space         │   │  ← 오래된 세대 (Old Generation)
│  ├─────────────────────┤   │     오래 살아남은 객체들이 위치
│  │   Large Object      │   │
│  │   Space             │   │  ← 큰 객체 전용 공간
│  ├─────────────────────┤   │
│  │   Code Space        │   │  ← 컴파일된 코드 저장
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │   Stack             │   │  ← 함수 호출, 지역 변수 저장
│  └─────────────────────┘   │
└─────────────────────────────┘
```

### Heap 영역 상세 설명

#### 1. **New Space (Young Generation) - 젊은 세대 영역**

**크기 및 특징:**
- 기본 크기: 1~8MB (플래그로 조정 가능: `--max-semi-space-size`)
- **새로 생성된 객체들이 처음 할당되는 공간**입니다
- 대부분의 객체는 짧은 생명주기를 가지므로 여기서 빠르게 생성되고 소멸됩니다
- **Semi-space 2개로 구성** (From-space, To-space): Scavenge 알고리즘을 위한 구조

**동작 원리:**
```javascript
// 예시: New Space에 할당되는 객체들
function handleRequest(req) {
  const tempData = { ...req.body };     // New Space에 할당
  const result = processData(tempData); // New Space에 할당
  return result;
  // 함수 종료 후 tempData는 곧 GC 대상이 됨
}

// 짧은 생명주기 객체 예시
for (let i = 0; i < 1000; i++) {
  const temp = { index: i, data: 'temporary' };  // New Space에 할당
  doSomething(temp);
  // 반복문 다음 사이클에서 GC 대상
}
```

#### 2. **Old Space (Old Generation) - 오래된 세대 영역**

**크기 및 특징:**
- 기본 크기: 약 1.4GB (64bit 시스템), 약 700MB (32bit 시스템)
- 플래그로 조정 가능: `--max-old-space-size`
- **New Space에서 2회 이상 GC에서 살아남은 객체들이 승격(Promotion)되어 이동**하는 공간
- 장기간 사용되는 객체들이 저장됩니다

**동작 원리:**
```javascript
// Old Space에 저장되는 객체 예시
const globalCache = new Map();        // 전역 객체 → Old Space
const config = require('./config');   // 설정 객체 → Old Space

class UserManager {
  constructor() {
    this.users = new Map();           // 오래 유지되는 데이터 → Old Space
  }

  addUser(id, data) {
    this.users.set(id, data);
  }
}

const userManager = new UserManager(); // 싱글톤 패턴 → Old Space
```

#### 3. **Large Object Space - 큰 객체 영역**

**특징:**
- 약 1MB 이상의 큰 객체들을 저장하는 별도 공간
- 다른 페이지로 이동하지 않고 여기에 고정됨
- GC의 일반적인 과정을 거치지 않음 (성능 최적화)

```javascript
// Large Object Space에 할당되는 예시
const largeBuffer = Buffer.alloc(2 * 1024 * 1024);  // 2MB 버퍼
const largeArray = new Array(500000).fill({         // 큰 배열
  id: 1,
  data: 'some data'
});
```

#### 4. **Code Space - 코드 영역**

**특징:**
- JIT(Just-In-Time) 컴파일된 코드가 저장되는 공간
- 자주 실행되는 함수는 최적화되어 여기에 저장됨

```javascript
// 반복 실행되는 함수는 최적화되어 Code Space에 저장
function hotFunction(x) {  // 자주 호출되면 JIT 컴파일됨
  return x * 2 + 1;
}

for (let i = 0; i < 100000; i++) {
  hotFunction(i);  // V8이 이 함수를 최적화
}
```

---

## 2. Garbage Collection 알고리즘

### GC의 필요성

JavaScript는 **자동 메모리 관리 언어**입니다. 개발자가 명시적으로 메모리를 할당하고 해제할 필요가 없으며, V8 엔진의 가비지 컬렉터가 자동으로 더 이상 사용하지 않는 메모리를 회수합니다.

### 2.1 Scavenge (Minor GC) - 마이너 가비지 컬렉션

#### 개념

**Scavenge**는 New Space에서 동작하는 **빠르고 자주 실행되는 GC**입니다. Cheney 알고리즘을 사용한 **복사 방식(Copying Collector)**으로 동작합니다.

#### 동작 원리

```javascript
/*
Scavenge 알고리즘 3단계:

1단계: From-space에서 살아있는 객체를 To-space로 복사
   - 루트(전역, 스택)에서 참조 가능한 객체만 복사
   - 참조되지 않는 객체는 자동으로 제거됨

2단계: From-space와 To-space를 교체 (swap)
   - 기존 To-space → 새로운 From-space
   - 기존 From-space → 새로운 To-space (비워짐)

3단계: 승격 (Promotion)
   - 2번 이상 살아남은 객체는 Old Space로 이동
   - 또는 To-space의 25% 이상 사용 시 승격
*/

// 실제 코드 예시
function processRequest(req) {
  // 1. tempData는 New Space의 From-space에 할당
  const tempData = {
    userId: req.userId,
    timestamp: Date.now(),
    payload: req.body
  };

  // 2. result도 New Space에 할당
  const result = transform(tempData);

  // 3. 함수 종료 시 tempData는 더 이상 참조되지 않음
  return result;

  // Scavenge GC 발생 시:
  // - result는 반환되어 외부에서 참조 → To-space로 복사
  // - tempData는 참조 없음 → 복사되지 않고 제거
}
```

#### 장단점

**장점:**
- 매우 빠름: 일반적으로 **1~10ms** 소요
- 메모리 조각화 없음 (연속된 공간에 복사)

**단점:**
- **Stop-the-World**: GC 실행 중 JavaScript 실행이 일시 중지됨
- 메모리 낭비: Semi-space 2개를 유지해야 하므로 실제 사용 가능한 공간은 절반

#### 실행 빈도

```javascript
// Scavenge는 자주 발생합니다
let allocCount = 0;

function allocateMemory() {
  const obj = new Array(1000).fill('data');
  allocCount++;

  if (allocCount % 1000 === 0) {
    console.log(`${allocCount}번 할당 - Scavenge 여러 번 발생`);
  }
}

// New Space가 가득 찰 때마다 Scavenge 실행
for (let i = 0; i < 100000; i++) {
  allocateMemory();
}
```

### 2.2 Mark-Sweep & Mark-Compact (Major GC) - 메이저 가비지 컬렉션

#### 개념

**Mark-Sweep**은 Old Space에서 동작하는 **느리지만 효율적인 GC**입니다. 큰 메모리 영역을 정리하며, 필요 시 **Mark-Compact**로 메모리 조각화를 해결합니다.

#### 3단계 동작 과정

```javascript
/*
Phase 1: Marking (표시 단계)
────────────────────────────
목적: 살아있는 객체를 찾아 표시

1. 루트(Root)에서 시작
   - 전역 객체 (global, window)
   - 현재 실행 컨텍스트의 지역 변수
   - 스택의 변수들

2. 그래프 순회 (Graph Traversal)
   - 루트에서 참조하는 모든 객체 방문
   - 각 객체가 참조하는 다른 객체도 재귀적으로 방문
   - 방문한 객체에 "마크(mark)" 표시

3. 마크되지 않은 객체 = 도달 불가능 = 가비지
*/

// Marking 예시
const globalCache = new Map();  // 루트에서 도달 가능 → 마킹됨

function createData() {
  const temp = { data: 'temporary' };  // 지역 변수
  const cached = { data: 'important' };

  globalCache.set('key', cached);  // cached는 globalCache가 참조 → 마킹됨

  return null;
  // temp는 함수 종료 후 도달 불가능 → 마킹 안됨 → 가비지
}

/*
Phase 2: Sweeping (제거 단계)
────────────────────────────
목적: 마킹되지 않은 객체 제거

1. 힙을 순차적으로 스캔
2. 마킹되지 않은 객체의 메모리 해제
3. 해제된 공간을 "free list"에 추가
   - 다음 할당 시 재사용 가능한 공간 목록
*/

// Sweeping 후 상태
// [마킹O][마킹X][마킹O][마킹X][마킹O]
//         ↓삭제        ↓삭제
// [마킹O][빈공간][마킹O][빈공간][마킹O]

/*
Phase 3: Compaction (압축 단계) - 필요 시만 실행
────────────────────────────────────────────
목적: 메모리 조각화 해결

1. 살아있는 객체들을 메모리의 한쪽 끝으로 이동
2. 연속된 빈 공간 확보
3. 포인터 업데이트
*/

// Compaction 전:
// [객체A][빈공간][객체B][빈공간][객체C]
// Compaction 후:
// [객체A][객체B][객체C][────큰 빈 공간────]
```

#### 실제 코드 예시

```javascript
// Mark-Sweep이 작동하는 시나리오
class UserCache {
  constructor() {
    this.users = new Map();  // Old Space에 할당
  }

  addUser(id, data) {
    this.users.set(id, data);
  }

  removeUser(id) {
    this.users.delete(id);  // 참조 제거
    // 삭제된 user 객체는 다음 Mark-Sweep에서 제거됨
  }
}

const cache = new UserCache();  // 전역 → 루트에서 도달 가능

// 사용자 추가
cache.addUser(1, { name: 'Alice' });  // Old Space로 승격
cache.addUser(2, { name: 'Bob' });

// 사용자 제거
cache.removeUser(1);
// Alice 객체는 더 이상 참조 안됨
// → 다음 Major GC의 Marking 단계에서 마킹 안됨
// → Sweeping 단계에서 메모리 해제
```

#### 성능 특성

```javascript
// Major GC는 느리고 덜 자주 발생
const v8 = require('v8');

console.log('GC 전:', process.memoryUsage().heapUsed / 1024 / 1024, 'MB');

// 대량 객체 생성 및 참조 해제
for (let i = 0; i < 1000000; i++) {
  global[`temp_${i}`] = { data: new Array(100) };
}

console.log('할당 후:', process.memoryUsage().heapUsed / 1024 / 1024, 'MB');

// 참조 제거
for (let i = 0; i < 1000000; i++) {
  delete global[`temp_${i}`];
}

// 강제 GC 실행 (--expose-gc 플래그 필요)
if (global.gc) {
  console.time('Major GC');
  global.gc();  // Mark-Sweep 실행: 100ms ~ 1초 이상 소요 가능
  console.timeEnd('Major GC');
}

console.log('GC 후:', process.memoryUsage().heapUsed / 1024 / 1024, 'MB');
```

### 2.3 Incremental Marking - 점진적 마킹

#### 문제점: Stop-the-World

전통적인 Mark-Sweep의 가장 큰 문제는 **애플리케이션 전체가 멈춘다**는 점입니다.

```javascript
// 문제 시나리오
const express = require('express');
const app = express();

const largeCache = new Map();

app.get('/api/data', (req, res) => {
  // 1. 요청 처리 중...
  const data = processRequest(req);

  // 2. 여기서 Major GC 발생!
  //    → 500ms 동안 애플리케이션 멈춤
  //    → 사용자는 응답을 받지 못함

  // 3. GC 종료 후 응답
  res.json(data);
  // 사용자 입장: 느린 응답 경험
});
```

#### Incremental Marking의 해결 방법

**작업을 여러 단계로 분할하여 애플리케이션 실행과 번갈아 진행**합니다.

```javascript
/*
전통적 방식 (Stop-the-World):
━━━━━━━━━━━━━━━━━━━━━━━━━━━
[App] → [──────── GC 500ms ────────] → [App]
         ↑ 애플리케이션 완전 정지


Incremental Marking 방식:
━━━━━━━━━━━━━━━━━━━━━━━━━━━
[App] → [GC 50ms] → [App 20ms] → [GC 50ms] → [App 20ms] → ... → [Sweep]
         ↑ 짧은 정지   ↑ 실행     ↑ 짧은 정지   ↑ 실행

총 GC 시간은 비슷하지만, 사용자가 느끼는 지연은 훨씬 적음
*/

// 타임라인 예시
/*
Time (ms):  0    50   70   120  140  190  210  260
           ─┬────┬────┬────┬────┬────┬────┬────┬─
Events:     │ GC │App │ GC │App │ GC │App │Sweep│
           ─┴────┴────┴────┴────┴────┴────┴────┴─

각 GC 단계는 힙의 일부만 마킹
애플리케이션은 중간중간 계속 실행 가능
*/
```

#### Write Barrier (쓰기 장벽)

Incremental Marking의 핵심 기술입니다.

```javascript
/*
문제: GC가 마킹 중일 때 애플리케이션이 객체 참조를 변경하면?

1. GC가 객체 A를 마킹함
2. 애플리케이션 실행: 객체 A가 새로운 객체 B를 참조하도록 변경
3. GC가 객체 B를 놓칠 수 있음 → 잘못된 메모리 해제!

해결책: Write Barrier
- 객체 참조가 변경될 때마다 V8에 알림
- 새로 참조된 객체를 마킹 대상에 추가
*/

// Write Barrier가 동작하는 예시 (내부 동작)
const obj = { data: 'original' };

// Incremental Marking 진행 중...
// obj는 이미 마킹됨

obj.newRef = { important: 'data' };
// ↑ Write Barrier 발동!
// V8이 newRef 객체를 마킹 큐에 추가
// → 다음 Incremental 단계에서 마킹됨
```

---

## 3. 메모리 누수 패턴과 해결법

### 메모리 누수란?

**메모리 누수(Memory Leak)**는 더 이상 필요하지 않은 메모리가 해제되지 않고 계속 점유되는 현상입니다. JavaScript는 가비지 컬렉션이 있지만, **의도치 않은 참조**로 인해 메모리 누수가 발생할 수 있습니다.

### 3.1 전역 변수 누수

#### 문제점

전역 변수는 **프로그램이 종료될 때까지 메모리에 유지**되며, GC의 대상이 되지 않습니다.

```javascript
// ❌ 나쁜 예: 전역 변수에 데이터 누적
let requestLog = [];  // 전역 변수

function handleRequest(req) {
  requestLog.push({
    timestamp: Date.now(),
    url: req.url,
    body: req.body,
    headers: req.headers
  });
  // requestLog는 계속 커지기만 함!
  // 1000개 요청 = 1000개 객체 메모리 점유
  // 10000개 요청 = 10000개 객체 메모리 점유 → 메모리 부족!
}

// 서버가 오래 실행되면...
// 메모리 사용량: 100MB → 500MB → 1GB → 2GB → 💥 크래시
```

#### 해결 방법

```javascript
// ✅ 좋은 예 1: 지역 변수 사용
function handleRequest(req) {
  const requestData = {  // 지역 변수
    timestamp: Date.now(),
    url: req.url
  };

  processRequest(requestData);

  return responseData;
  // 함수 종료 후 requestData는 GC 대상
}

// ✅ 좋은 예 2: 크기 제한이 있는 전역 캐시
class LimitedCache {
  constructor(maxSize = 100) {
    this.cache = [];
    this.maxSize = maxSize;
  }

  add(item) {
    this.cache.push(item);

    // FIFO: 가장 오래된 항목 제거
    if (this.cache.length > this.maxSize) {
      const removed = this.cache.shift();
      console.log('오래된 항목 제거:', removed);
      // removed는 이제 GC 대상
    }
  }
}

const requestLog = new LimitedCache(1000);  // 최대 1000개만 유지

function handleRequest(req) {
  requestLog.add({
    timestamp: Date.now(),
    url: req.url
  });
  // 항상 최대 1000개만 유지됨
}
```

### 3.2 클로저 메모리 누수

#### 클로저의 메모리 동작 원리

클로저는 **외부 함수의 변수를 내부 함수에서 참조**할 수 있게 하는 JavaScript의 강력한 기능입니다. 하지만 **의도치 않게 큰 객체를 참조**하면 메모리 누수가 발생합니다.

```javascript
// ❌ 나쁜 예: 클로저가 불필요한 큰 객체를 참조
function createUserHandler(userId) {
  // 사용자 데이터 로드 (매우 큰 객체라고 가정)
  const userData = {
    id: userId,
    profile: { /* 1MB 데이터 */ },
    history: [ /* 10MB 데이터 */ ],
    analytics: { /* 5MB 데이터 */ }
  };

  // 간단한 핸들러 함수 반환
  return function simpleHandler() {
    console.log(`Handler for user ${userId}`);
    // userId만 사용하는데...
  };

  // 문제:
  // simpleHandler가 userId를 참조
  // → JavaScript 엔진이 전체 외부 스코프를 유지
  // → userData도 함께 메모리에 남음 (16MB 낭비!)
}

const handlers = [];
for (let i = 0; i < 1000; i++) {
  handlers.push(createUserHandler(i));
}
// 총 메모리 사용: 1000 * 16MB = 16GB! 💥
```

#### 해결 방법

```javascript
// ✅ 좋은 예 1: 필요한 데이터만 추출
function createUserHandler(userId) {
  const userData = loadLargeUserData(userId);  // 16MB

  // 필요한 것만 추출
  const userIdOnly = userData.id;  // 작은 데이터

  // userData는 여기서 더 이상 참조 안됨
  // → 함수 종료 후 GC 대상

  return function simpleHandler() {
    console.log(`Handler for user ${userIdOnly}`);
    // 클로저는 userIdOnly(작은 값)만 참조
  };
}

// ✅ 좋은 예 2: 즉시 실행 함수로 스코프 분리
function createUserHandler(userId) {
  const userData = loadLargeUserData(userId);

  // 필요한 작업 즉시 실행
  const summary = (function() {
    return {
      id: userData.id,
      name: userData.profile.name
    };
  })();
  // userData는 즉시 실행 함수 종료 후 GC 대상

  return function handler() {
    console.log('User:', summary.name);
    // summary만 참조 (작은 객체)
  };
}

// ✅ 좋은 예 3: 명시적 null 할당
function createUserHandler(userId) {
  let userData = loadLargeUserData(userId);

  const needed = {
    id: userData.id,
    name: userData.profile.name
  };

  userData = null;  // 명시적으로 참조 해제
  // 큰 객체는 즉시 GC 대상이 됨

  return function handler() {
    console.log('User:', needed.name);
  };
}
```

#### 클로저 메모리 누수의 실제 사례

```javascript
// 실제 프로덕션에서 발생한 메모리 누수 사례
function setupWebSocketHandler(socket) {
  const connectionData = {
    socket: socket,
    largeBuffer: Buffer.alloc(10 * 1024 * 1024),  // 10MB
    history: []
  };

  // 이벤트 핸들러들
  socket.on('message', (msg) => {
    connectionData.history.push(msg);  // 계속 누적!
  });

  socket.on('close', () => {
    console.log('Connection closed');
    // 문제: socket은 close되었지만
    // message 핸들러가 여전히 connectionData 참조!
    // → 소켓이 닫혀도 10MB + history가 메모리에 남음
  });
}

// 해결책
function setupWebSocketHandlerFixed(socket) {
  const MAX_HISTORY = 100;
  const history = [];

  const messageHandler = (msg) => {
    history.push(msg);
    if (history.length > MAX_HISTORY) {
      history.shift();  // 오래된 것 제거
    }
  };

  const closeHandler = () => {
    // 명시적으로 리스너 제거
    socket.removeListener('message', messageHandler);
    socket.removeListener('close', closeHandler);

    // 메모리 정리
    history.length = 0;
  };

  socket.on('message', messageHandler);
  socket.on('close', closeHandler);
}
```

### 3.3 이벤트 리스너 누수

#### 문제점

이벤트 리스너는 **명시적으로 제거하지 않으면** 계속 메모리에 남아있으며, 리스너가 참조하는 모든 객체도 GC되지 않습니다.

```javascript
// ❌ 나쁜 예: 리스너를 제거하지 않음
const EventEmitter = require('events');
const emitter = new EventEmitter();

function processData() {
  const largeData = Buffer.alloc(10 * 1024 * 1024);  // 10MB

  // 리스너 등록
  emitter.on('update', () => {
    console.log('Data size:', largeData.length);
  });

  // 함수 종료
  // 문제: 리스너가 largeData를 계속 참조
  // → largeData는 GC 불가능
}

// 100번 호출
for (let i = 0; i < 100; i++) {
  processData();
}
// 결과: 100개의 리스너 + 100 * 10MB = 1GB 메모리 사용!
// 경고: MaxListenersExceededWarning 발생
```

#### 해결 방법

```javascript
// ✅ 좋은 예 1: removeListener로 정리
function processDataFixed() {
  const largeData = Buffer.alloc(10 * 1024 * 1024);

  // 리스너 함수를 변수에 저장
  const updateListener = () => {
    console.log('Data size:', largeData.length);
  };

  emitter.on('update', updateListener);

  // 작업 완료 후 리스너 제거
  setTimeout(() => {
    emitter.removeListener('update', updateListener);
    // 이제 largeData는 GC 대상
  }, 5000);
}

// ✅ 좋은 예 2: once로 일회성 리스너 등록
function processDataOnce() {
  const largeData = Buffer.alloc(10 * 1024 * 1024);

  // once: 한 번 실행 후 자동으로 제거
  emitter.once('update', () => {
    console.log('Data size:', largeData.length);
  });
  // 이벤트 발생 후 자동으로 리스너 제거 → largeData GC 가능
}

// ✅ 좋은 예 3: 정리 함수 패턴
function setupListener() {
  const largeData = Buffer.alloc(10 * 1024 * 1024);

  const listener = () => {
    console.log('Data size:', largeData.length);
  };

  emitter.on('update', listener);

  // 정리 함수 반환
  return function cleanup() {
    emitter.removeListener('update', listener);
    console.log('Listener cleaned up');
  };
}

const cleanup = setupListener();
// 나중에...
cleanup();  // 명시적으로 정리
```

#### EventEmitter 누수 감지 및 방지

```javascript
// EventEmitter는 기본적으로 10개 이상의 리스너 등록 시 경고
const EventEmitter = require('events');
const emitter = new EventEmitter();

// 리스너 추적 클래스
class SafeEventEmitter extends EventEmitter {
  constructor() {
    super();
    this.listenerInfo = new Map();
  }

  on(event, listener) {
    super.on(event, listener);

    // 리스너 정보 저장
    const stack = new Error().stack;
    this.listenerInfo.set(listener, {
      event,
      addedAt: new Date(),
      stack
    });

    return this;
  }

  removeListener(event, listener) {
    super.removeListener(event, listener);
    this.listenerInfo.delete(listener);
    return this;
  }

  // 오래된 리스너 감지
  checkStalenessListeners(maxAgeMs = 60000) {
    const now = Date.now();

    this.listenerInfo.forEach((info, listener) => {
      const age = now - info.addedAt.getTime();

      if (age > maxAgeMs) {
        console.warn(`⚠️ 오래된 리스너 감지: ${info.event}`);
        console.warn(`등록 시간: ${info.addedAt}`);
        console.warn(`나이: ${age}ms`);
        console.warn(info.stack);
      }
    });
  }
}

// 사용 예
const safeEmitter = new SafeEventEmitter();

safeEmitter.on('data', () => {});
safeEmitter.on('data', () => {});

// 주기적으로 체크
setInterval(() => {
  safeEmitter.checkStalenessListeners(30000);  // 30초 이상된 리스너 경고
}, 10000);
```

### 3.4 타이머 누수

#### 문제점

`setInterval`과 `setTimeout`은 **명시적으로 정리하지 않으면** 계속 실행되며, 타이머 콜백이 참조하는 모든 객체를 메모리에 유지합니다.

```javascript
// ❌ 나쁜 예: 타이머를 정리하지 않음
function startDataPolling(userId) {
  const userData = loadUserData(userId);  // 큰 객체
  const cache = new Map();

  setInterval(() => {
    const newData = fetchDataFromAPI();
    cache.set(Date.now(), newData);
    // cache가 계속 커짐!
    console.log('Polling for user:', userData.name);
  }, 1000);

  // 문제:
  // 1. setInterval이 계속 실행됨 → CPU 낭비
  // 2. cache가 계속 커짐 → 메모리 누수
  // 3. userData가 계속 참조됨 → GC 불가
}

// 사용자가 로그아웃해도...
startDataPolling(123);
// 타이머는 계속 실행! 메모리도 계속 점유!
```

#### 해결 방법

```javascript
// ✅ 좋은 예 1: clearInterval로 정리
function startDataPollingFixed(userId) {
  const userData = loadUserData(userId);
  const cache = new Map();
  const MAX_CACHE_SIZE = 100;

  const intervalId = setInterval(() => {
    const newData = fetchDataFromAPI();

    // 캐시 크기 제한
    if (cache.size >= MAX_CACHE_SIZE) {
      const oldestKey = cache.keys().next().value;
      cache.delete(oldestKey);
    }

    cache.set(Date.now(), newData);
  }, 1000);

  // 정리 함수 반환
  return function stopPolling() {
    clearInterval(intervalId);
    cache.clear();
    console.log('Polling stopped');
  };
}

const stopPolling = startDataPollingFixed(123);

// 사용자 로그아웃 시
stopPolling();  // 타이머 정리 → 메모리 해제

// ✅ 좋은 예 2: 클래스로 관리
class DataPoller {
  constructor(userId) {
    this.userId = userId;
    this.cache = new Map();
    this.intervalId = null;
    this.maxCacheSize = 100;
  }

  start() {
    if (this.intervalId) {
      console.warn('Already started');
      return;
    }

    this.intervalId = setInterval(() => {
      this.poll();
    }, 1000);

    console.log(`Polling started for user ${this.userId}`);
  }

  poll() {
    const newData = fetchDataFromAPI();

    if (this.cache.size >= this.maxCacheSize) {
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
    }

    this.cache.set(Date.now(), newData);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      console.log(`Polling stopped for user ${this.userId}`);
    }
  }

  destroy() {
    this.stop();
    this.cache.clear();
    this.cache = null;
  }
}

// 사용
const poller = new DataPoller(123);
poller.start();

// 로그아웃 시
poller.destroy();  // 완전히 정리
```

#### setTimeout 누수 주의

```javascript
// ❌ 나쁜 예: setTimeout 체인
function recursiveTimeout() {
  const largeData = new Array(100000);

  setTimeout(() => {
    processData(largeData);
    recursiveTimeout();  // 재귀적으로 계속 호출
  }, 1000);

  // 문제: 각 호출마다 largeData가 새로 생성됨
  // → 콜 스택에 계속 쌓임
}

// ✅ 좋은 예: setInterval 사용
function intervalPattern() {
  const intervalId = setInterval(() => {
    const largeData = new Array(100000);
    processData(largeData);
    // largeData는 콜백 종료 후 GC 대상
  }, 1000);

  return () => clearInterval(intervalId);
}
```

---

## 4. 메모리 모니터링

### 4.1 process.memoryUsage() - 기본 메모리 측정

#### 반환값 설명

```javascript
function checkMemory() {
  const usage = process.memoryUsage();

  console.log({
    // RSS (Resident Set Size)
    // - 프로세스가 차지하는 총 물리 메모리 (RAM)
    // - Heap + Stack + Code + 외부 라이브러리 메모리 포함
    rss: `${Math.round(usage.rss / 1024 / 1024)} MB`,

    // Heap Total
    // - V8이 할당한 전체 힙 메모리 크기
    // - 실제 사용량이 아니라 예약된 크기
    heapTotal: `${Math.round(usage.heapTotal / 1024 / 1024)} MB`,

    // Heap Used
    // - 실제로 사용 중인 힙 메모리
    // - **가장 중요한 지표**: 이 값이 계속 증가하면 메모리 누수 의심
    heapUsed: `${Math.round(usage.heapUsed / 1024 / 1024)} MB`,

    // External
    // - V8 외부의 C++ 객체에 바인딩된 메모리
    // - Buffer, Crypto 등에서 사용
    external: `${Math.round(usage.external / 1024 / 1024)} MB`,

    // Array Buffers
    // - ArrayBuffer와 SharedArrayBuffer가 사용하는 메모리
    arrayBuffers: `${Math.round(usage.arrayBuffers / 1024 / 1024)} MB`
  });
}

// 사용 예
checkMemory();
// 출력:
// {
//   rss: '50 MB',
//   heapTotal: '20 MB',
//   heapUsed: '15 MB',
//   external: '2 MB',
//   arrayBuffers: '1 MB'
// }
```

#### 메모리 증가 감지

```javascript
// 메모리 누수 감지 예시
function detectMemoryLeak() {
  const samples = [];
  const SAMPLE_COUNT = 10;

  const intervalId = setInterval(() => {
    const usage = process.memoryUsage();
    samples.push(usage.heapUsed);

    if (samples.length > SAMPLE_COUNT) {
      samples.shift();  // 오래된 샘플 제거
    }

    // 평균 증가율 계산
    if (samples.length === SAMPLE_COUNT) {
      let totalGrowth = 0;
      for (let i = 1; i < samples.length; i++) {
        totalGrowth += samples[i] - samples[i - 1];
      }

      const avgGrowth = totalGrowth / (samples.length - 1);
      const avgGrowthMB = avgGrowth / 1024 / 1024;

      console.log(`평균 메모리 증가율: ${avgGrowthMB.toFixed(2)} MB/interval`);

      // 지속적으로 증가하면 경고
      if (avgGrowthMB > 0.5) {  // 0.5MB 이상 증가
        console.warn('⚠️ 메모리 누수 가능성 있음!');
        console.warn(`현재 사용량: ${Math.round(usage.heapUsed / 1024 / 1024)} MB`);
      }
    }
  }, 5000);  // 5초마다 체크

  return () => clearInterval(intervalId);
}

const stopMonitoring = detectMemoryLeak();
```

### 4.2 Heap Snapshot - 힙 스냅샷 분석

#### 스냅샷 생성

힙 스냅샷은 **특정 시점의 메모리 상태를 파일로 저장**하여 Chrome DevTools에서 분석할 수 있게 합니다.

```javascript
const v8 = require('v8');
const fs = require('fs');

// 스냅샷 저장 함수
function takeHeapSnapshot(filename) {
  const snapshotPath = v8.writeHeapSnapshot(filename);
  const stats = fs.statSync(snapshotPath);

  console.log(`Heap snapshot saved: ${snapshotPath}`);
  console.log(`Size: ${Math.round(stats.size / 1024 / 1024)} MB`);

  return snapshotPath;
}

// 사용 시나리오: 메모리 누수 추적
console.log('1. 초기 상태 스냅샷');
takeHeapSnapshot('./snapshots/heap-baseline.heapsnapshot');

// 애플리케이션 실행
const leakyArray = [];
for (let i = 0; i < 100000; i++) {
  leakyArray.push({
    id: i,
    data: new Array(100).fill('leak')
  });
}

console.log('2. 메모리 사용 후 스냅샷');
takeHeapSnapshot('./snapshots/heap-after-leak.heapsnapshot');

// Chrome DevTools에서 비교:
// 1. chrome://inspect 열기
// 2. "Open dedicated DevTools for Node" 클릭
// 3. Memory 탭 → Load 버튼으로 스냅샷 로드
// 4. 두 스냅샷을 Comparison 모드로 비교
//    → 어떤 객체가 증가했는지 확인 가능
```

#### 자동 스냅샷 (메모리 임계값 초과 시)

```javascript
class AutoSnapshotManager {
  constructor(thresholdMB = 500, snapshotDir = './snapshots') {
    this.threshold = thresholdMB * 1024 * 1024;
    this.snapshotDir = snapshotDir;
    this.snapshotCount = 0;

    // 디렉토리 생성
    if (!fs.existsSync(snapshotDir)) {
      fs.mkdirSync(snapshotDir, { recursive: true });
    }
  }

  start(checkInterval = 10000) {
    this.intervalId = setInterval(() => {
      const usage = process.memoryUsage();

      if (usage.heapUsed > this.threshold) {
        console.warn(`⚠️ 메모리 임계값 초과: ${Math.round(usage.heapUsed / 1024 / 1024)} MB`);
        this.takeSnapshot();
      }
    }, checkInterval);
  }

  takeSnapshot() {
    this.snapshotCount++;
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `${this.snapshotDir}/heap-${timestamp}-${this.snapshotCount}.heapsnapshot`;

    console.log('스냅샷 생성 중...');
    const path = v8.writeHeapSnapshot(filename);
    console.log(`스냅샷 저장됨: ${path}`);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  }
}

// 사용
const snapshotManager = new AutoSnapshotManager(500);  // 500MB 임계값
snapshotManager.start(10000);  // 10초마다 체크
```

### 4.3 실시간 메모리 추적

#### 고급 메모리 모니터

```javascript
class MemoryMonitor {
  constructor(options = {}) {
    this.thresholdMB = options.thresholdMB || 500;
    this.threshold = this.thresholdMB * 1024 * 1024;
    this.samples = [];
    this.maxSamples = options.maxSamples || 100;
    this.alertCallback = options.onAlert || null;
  }

  start(interval = 5000) {
    console.log(`메모리 모니터링 시작 (임계값: ${this.thresholdMB}MB, 간격: ${interval}ms)`);

    this.intervalId = setInterval(() => {
      this.collect();
    }, interval);
  }

  collect() {
    const usage = process.memoryUsage();
    const sample = {
      timestamp: Date.now(),
      heapUsed: usage.heapUsed,
      heapTotal: usage.heapTotal,
      rss: usage.rss,
      external: usage.external
    };

    this.samples.push(sample);

    // 오래된 샘플 제거
    if (this.samples.length > this.maxSamples) {
      this.samples.shift();
    }

    // 임계값 체크
    if (usage.heapUsed > this.threshold) {
      this.handleThresholdExceeded(sample);
    }

    // 메모리 증가 추세 분석
    if (this.samples.length >= 10) {
      this.analyzeGrowthTrend();
    }
  }

  handleThresholdExceeded(sample) {
    const heapMB = Math.round(sample.heapUsed / 1024 / 1024);
    console.warn(`⚠️ 메모리 임계값 초과!`);
    console.warn(`현재: ${heapMB}MB / 임계값: ${this.thresholdMB}MB`);

    if (this.alertCallback) {
      this.alertCallback({
        type: 'threshold_exceeded',
        current: heapMB,
        threshold: this.thresholdMB,
        sample
      });
    }
  }

  analyzeGrowthTrend() {
    const recent = this.samples.slice(-10);

    // 평균 증가율 계산
    let totalGrowth = 0;
    for (let i = 1; i < recent.length; i++) {
      totalGrowth += recent[i].heapUsed - recent[i - 1].heapUsed;
    }

    const avgGrowth = totalGrowth / (recent.length - 1);
    const avgGrowthMB = avgGrowth / 1024 / 1024;

    // 지속적인 증가 감지
    if (avgGrowth > 0) {
      const allIncreasing = recent.every((sample, i) => {
        if (i === 0) return true;
        return sample.heapUsed >= recent[i - 1].heapUsed;
      });

      if (allIncreasing) {
        console.warn(`⚠️ 메모리 누수 가능성!`);
        console.warn(`평균 증가율: ${avgGrowthMB.toFixed(2)} MB/interval`);

        if (this.alertCallback) {
          this.alertCallback({
            type: 'possible_leak',
            growthRate: avgGrowthMB,
            samples: recent
          });
        }
      }
    }
  }

  getReport() {
    if (this.samples.length === 0) {
      return { error: '수집된 샘플 없음' };
    }

    const latest = this.samples[this.samples.length - 1];
    const oldest = this.samples[0];

    const totalGrowth = latest.heapUsed - oldest.heapUsed;
    const totalGrowthMB = totalGrowth / 1024 / 1024;
    const duration = latest.timestamp - oldest.timestamp;
    const durationMin = duration / 1000 / 60;

    return {
      current: {
        heapUsed: Math.round(latest.heapUsed / 1024 / 1024) + ' MB',
        heapTotal: Math.round(latest.heapTotal / 1024 / 1024) + ' MB',
        rss: Math.round(latest.rss / 1024 / 1024) + ' MB'
      },
      trend: {
        totalGrowth: totalGrowthMB.toFixed(2) + ' MB',
        duration: durationMin.toFixed(2) + ' min',
        growthRate: (totalGrowthMB / durationMin).toFixed(2) + ' MB/min'
      },
      sampleCount: this.samples.length
    };
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      console.log('메모리 모니터링 중지');
      console.log('최종 리포트:', this.getReport());
    }
  }
}

// 사용 예
const monitor = new MemoryMonitor({
  thresholdMB: 500,
  maxSamples: 100,
  onAlert: (alert) => {
    console.error('🚨 메모리 알림:', alert);

    // 알림 전송 (Slack, Email 등)
    // sendAlertToSlack(alert);

    // 힙 스냅샷 자동 생성
    if (alert.type === 'possible_leak') {
      const v8 = require('v8');
      v8.writeHeapSnapshot(`./leak-${Date.now()}.heapsnapshot`);
    }
  }
});

monitor.start(5000);  // 5초마다 체크

// 30초 후 리포트 출력
setTimeout(() => {
  console.log('현재 상태:', monitor.getReport());
}, 30000);

// 종료 시
process.on('SIGINT', () => {
  monitor.stop();
  process.exit();
});
```

---

## 5. V8 플래그를 통한 메모리 최적화

### 5.1 힙 크기 조정

#### Old Space 크기 설정

```bash
# 기본값: 약 1.4GB (64bit), 700MB (32bit)
# 메모리가 충분한 서버에서는 크기를 늘려야 함

# 4GB로 설정
node --max-old-space-size=4096 app.js

# 8GB로 설정 (대용량 데이터 처리)
node --max-old-space-size=8192 app.js

# 2GB로 설정
node --max-old-space-size=2048 app.js

# 왜 조정이 필요한가?
# - 기본값은 웹 애플리케이션용으로 설정됨
# - 대용량 데이터 처리, 머신러닝 등에서는 부족할 수 있음
# - 힙이 가득 차면 "JavaScript heap out of memory" 에러 발생
```

#### New Space 크기 설정

```bash
# 기본값: 약 16MB
# New Space가 크면 Scavenge GC 빈도는 줄지만, 한 번의 GC 시간은 늘어남

# Semi-space를 16MB로 설정 (New Space 총 32MB)
node --max-semi-space-size=16 app.js

# Semi-space를 8MB로 설정 (New Space 총 16MB)
node --max-semi-space-size=8 app.js

# 조정 가이드:
# - 객체 생성이 많은 앱: 크게 설정 → GC 빈도 감소
# - 응답 시간이 중요한 앱: 작게 설정 → GC 시간 단축
```

#### 실제 사용 사례

```javascript
// package.json에 스크립트 추가
{
  "scripts": {
    // 개발 환경: 기본 설정
    "dev": "node app.js",

    // 프로덕션: 메모리 최적화
    "start": "node --max-old-space-size=4096 app.js",

    // 대용량 배치 작업
    "batch": "node --max-old-space-size=8192 --max-semi-space-size=32 batch-processor.js",

    // 메모리 제약 환경 (컨테이너 등)
    "start:constrained": "node --max-old-space-size=512 app.js"
  }
}
```

### 5.2 GC 최적화 플래그

#### GC 로그 활성화

```bash
# 기본 GC 로그
node --trace-gc app.js

# 출력 예시:
# [16852:0x104008000]       65 ms: Scavenge 2.8 (4.2) -> 2.1 (5.2) MB, 1.2 / 0.0 ms  (average mu = 1.000, current mu = 1.000) allocation failure
# [16852:0x104008000]      145 ms: Scavenge 3.1 (5.2) -> 2.4 (6.2) MB, 1.5 / 0.0 ms  (average mu = 1.000, current mu = 1.000) allocation failure

# 해석:
# - 65 ms: 애플리케이션 시작 후 65ms 시점
# - Scavenge: GC 타입 (Scavenge = Minor GC)
# - 2.8 (4.2) -> 2.1 (5.2) MB:
#   * 2.8MB → 2.1MB: 사용된 힙 크기
#   * (4.2) → (5.2): 총 힙 크기
# - 1.2 ms: GC 소요 시간

# 상세 GC 통계
node --trace-gc --trace-gc-verbose app.js

# GC 이벤트를 파일로 저장
node --trace-gc app.js 2> gc.log
```

#### GC 동작 제어

```bash
# GC 강제 실행 허용 (디버깅용)
node --expose-gc app.js

# 코드에서 사용:
if (global.gc) {
  console.log('메모리 정리 전:', process.memoryUsage().heapUsed);
  global.gc();  // 강제 GC 실행
  console.log('메모리 정리 후:', process.memoryUsage().heapUsed);
}

# Incremental marking 비활성화 (디버깅/벤치마크용)
node --noincremental-marking app.js

# Concurrent marking 활성화 (V8 최신 버전)
node --concurrent-marking app.js

# 주의: 프로덕션에서는 기본 설정 사용 권장
```

### 5.3 프로덕션 최적화 설정

#### 환경별 최적화

```javascript
// package.json - 다양한 환경 설정
{
  "scripts": {
    // 개발 환경
    "dev": "node --trace-warnings app.js",

    // 프로덕션 (일반)
    "start:prod": "node --max-old-space-size=4096 app.js",

    // 프로덕션 (고성능)
    "start:perf": "node --max-old-space-size=4096 --optimize-for-size --gc-interval=100 app.js",

    // 메모리 모니터링
    "start:monitor": "node --max-old-space-size=4096 --trace-gc app.js 2> logs/gc-$(date +%Y%m%d-%H%M%S).log",

    // Docker 컨테이너 (제한된 메모리)
    "start:docker": "node --max-old-space-size=512 --optimize-for-size app.js",

    // 디버깅 (메모리 문제 진단)
    "debug:memory": "node --expose-gc --trace-gc --trace-gc-verbose --max-old-space-size=2048 app.js"
  }
}
```

#### 자동 메모리 조정 스크립트

```javascript
// auto-memory-config.js
// 시스템 메모리에 따라 자동으로 힙 크기 조정

const os = require('os');
const { spawn } = require('child_process');

function getOptimalHeapSize() {
  const totalMemoryGB = os.totalmem() / 1024 / 1024 / 1024;

  // 전체 메모리의 50%를 Node.js에 할당
  const heapSizeGB = Math.floor(totalMemoryGB * 0.5);
  const heapSizeMB = heapSizeGB * 1024;

  console.log(`시스템 총 메모리: ${totalMemoryGB.toFixed(2)} GB`);
  console.log(`Node.js 힙 크기: ${heapSizeGB} GB (${heapSizeMB} MB)`);

  return heapSizeMB;
}

function startApp() {
  const heapSize = getOptimalHeapSize();

  const args = [
    `--max-old-space-size=${heapSize}`,
    '--max-semi-space-size=32',
    'app.js'
  ];

  console.log(`실행 명령: node ${args.join(' ')}`);

  const child = spawn('node', args, {
    stdio: 'inherit'
  });

  child.on('exit', (code) => {
    console.log(`앱 종료: ${code}`);
    process.exit(code);
  });
}

startApp();

// 사용: node auto-memory-config.js
```

---

## 6. 메모리 효율적인 코딩 패턴

### 6.1 스트림 사용

#### 스트림이 필요한 이유

파일이나 네트워크 데이터를 처리할 때, 전체 데이터를 메모리에 로드하면 메모리 부족이 발생할 수 있습니다. 스트림은 **데이터를 청크(chunk) 단위로 처리**하여 메모리 사용을 최소화합니다.

```javascript
const fs = require('fs');

// ❌ 나쁜 예: 전체 파일을 메모리에 로드
async function processLargeFile() {
  try {
    // 10GB 파일을 읽으면?
    const content = await fs.promises.readFile('large-file.txt');
    // → 10GB 메모리 사용!
    // → "JavaScript heap out of memory" 에러 발생 가능

    const lines = content.toString().split('\n');
    for (const line of lines) {
      processLine(line);
    }
  } catch (error) {
    console.error('메모리 부족:', error);
  }
}

// ✅ 좋은 예: 스트림으로 청크 단위 처리
function processLargeFileStream() {
  const readStream = fs.createReadStream('large-file.txt', {
    encoding: 'utf8',
    highWaterMark: 64 * 1024  // 64KB씩 읽기
  });

  let buffer = '';

  readStream.on('data', (chunk) => {
    // chunk는 64KB만 메모리 점유
    buffer += chunk;

    // 줄 단위로 처리
    const lines = buffer.split('\n');
    buffer = lines.pop();  // 마지막 불완전한 줄은 보관

    lines.forEach(line => {
      processLine(line);
    });

    // 청크 처리 후 메모리 해제됨
  });

  readStream.on('end', () => {
    if (buffer.length > 0) {
      processLine(buffer);
    }
    console.log('처리 완료');
  });

  readStream.on('error', (error) => {
    console.error('오류:', error);
  });
}

// 10GB 파일도 최대 64KB만 메모리 사용!
```

#### 실전 스트림 패턴

```javascript
const fs = require('fs');
const { Transform, pipeline } = require('stream');
const zlib = require('zlib');

// Transform 스트림: 데이터 변환
class UpperCaseTransform extends Transform {
  _transform(chunk, encoding, callback) {
    // 청크를 대문자로 변환
    const upperChunk = chunk.toString().toUpperCase();
    this.push(upperChunk);
    callback();
  }
}

// CSV 파싱 Transform
class CSVParser extends Transform {
  constructor() {
    super({ objectMode: true });
    this.buffer = '';
    this.headers = null;
  }

  _transform(chunk, encoding, callback) {
    this.buffer += chunk.toString();
    const lines = this.buffer.split('\n');
    this.buffer = lines.pop();

    lines.forEach((line, index) => {
      if (!this.headers) {
        this.headers = line.split(',');
      } else {
        const values = line.split(',');
        const row = {};
        this.headers.forEach((header, i) => {
          row[header] = values[i];
        });
        this.push(row);  // 객체 형태로 전달
      }
    });

    callback();
  }

  _flush(callback) {
    if (this.buffer.length > 0) {
      // 마지막 줄 처리
      const values = this.buffer.split(',');
      const row = {};
      this.headers.forEach((header, i) => {
        row[header] = values[i];
      });
      this.push(row);
    }
    callback();
  }
}

// 파이프라인으로 여러 스트림 연결
function processCSV() {
  pipeline(
    fs.createReadStream('large-data.csv'),  // 읽기
    new CSVParser(),                         // CSV 파싱
    new Transform({
      objectMode: true,
      transform(row, encoding, callback) {
        // 데이터 필터링 및 변환
        if (row.age > 18) {
          this.push(JSON.stringify(row) + '\n');
        }
        callback();
      }
    }),
    zlib.createGzip(),                       // 압축
    fs.createWriteStream('output.json.gz'),  // 저장
    (err) => {
      if (err) {
        console.error('파이프라인 오류:', err);
      } else {
        console.log('처리 완료');
      }
    }
  );
}

// 수 GB 파일도 메모리 효율적으로 처리!
```

### 6.2 객체 풀링 (Object Pooling)

#### 개념

객체 풀링은 **객체를 재사용**하여 GC 압력을 줄이는 기법입니다. 빈번하게 생성/삭제되는 객체에 효과적입니다.

```javascript
// 왜 필요한가?
// 1초에 1000개의 객체 생성 → 1초에 1000번의 메모리 할당 → GC 부담
// 객체 풀: 10개의 객체만 생성하고 재사용 → GC 부담 감소

class ObjectPool {
  constructor(factory, reset, size = 100) {
    this.factory = factory;  // 객체 생성 함수
    this.reset = reset;      // 객체 초기화 함수
    this.pool = [];
    this.size = size;
    this.created = 0;
  }

  acquire() {
    // 풀에 사용 가능한 객체가 있으면 재사용
    if (this.pool.length > 0) {
      return this.pool.pop();
    }

    // 없으면 새로 생성
    if (this.created < this.size) {
      this.created++;
      return this.factory();
    }

    // 풀이 가득 차면 새로 생성 (풀 크기 초과)
    console.warn('Pool exhausted, creating new object');
    return this.factory();
  }

  release(obj) {
    // 객체를 초기화하고 풀에 반환
    if (this.pool.length < this.size) {
      this.reset(obj);
      this.pool.push(obj);
    }
    // 풀이 가득 차면 버림 (GC 대상)
  }

  getStats() {
    return {
      poolSize: this.pool.length,
      totalCreated: this.created,
      maxSize: this.size
    };
  }
}

// 실제 사용 예: Buffer 풀링
const bufferPool = new ObjectPool(
  () => Buffer.allocUnsafe(1024),  // 1KB 버퍼 생성
  (buf) => buf.fill(0),             // 버퍼 초기화
  50                                 // 최대 50개 유지
);

// 고성능 데이터 처리
function processDataWithPool(data) {
  const buffer = bufferPool.acquire();  // 풀에서 가져오기

  try {
    buffer.write(data);
    const result = performOperation(buffer);
    return result;
  } finally {
    bufferPool.release(buffer);  // 풀에 반환
  }
}

// 벤치마크
console.time('Without pool');
for (let i = 0; i < 100000; i++) {
  const buffer = Buffer.allocUnsafe(1024);  // 매번 생성
  buffer.write('data');
  // buffer는 GC 대상
}
console.timeEnd('Without pool');  // ~200ms

console.time('With pool');
for (let i = 0; i < 100000; i++) {
  const buffer = bufferPool.acquire();  // 재사용
  buffer.write('data');
  bufferPool.release(buffer);
}
console.timeEnd('With pool');  // ~50ms (4배 빠름!)

console.log('Pool stats:', bufferPool.getStats());
```

#### HTTP 요청 객체 풀링

```javascript
// Express 앱에서 응답 객체 풀링
class ResponseObjectPool {
  constructor(size = 100) {
    this.pool = [];
    this.size = size;
  }

  acquire() {
    if (this.pool.length > 0) {
      return this.pool.pop();
    }

    return {
      statusCode: 200,
      headers: {},
      body: null
    };
  }

  release(obj) {
    // 초기화
    obj.statusCode = 200;
    obj.headers = {};
    obj.body = null;

    if (this.pool.length < this.size) {
      this.pool.push(obj);
    }
  }
}

const responsePool = new ResponseObjectPool(200);

// Express 미들웨어
app.use((req, res, next) => {
  const responseObj = responsePool.acquire();

  res.on('finish', () => {
    responsePool.release(responseObj);
  });

  req.responseObj = responseObj;
  next();
});
```

### 6.3 WeakMap/WeakSet 활용

#### WeakMap의 특별한 점

`WeakMap`은 **키가 GC되면 자동으로 항목이 제거**되는 특수한 Map입니다. 메모리 누수를 방지하는 강력한 도구입니다.

```javascript
// 일반 Map vs WeakMap

// ❌ 일반 Map: 메모리 누수 발생
const normalMap = new Map();

function processUser(user) {
  // user 객체를 키로 사용
  normalMap.set(user, {
    lastAccess: Date.now(),
    permissions: ['read', 'write']
  });
}

let user = { id: 1, name: 'Alice' };
processUser(user);

user = null;  // user 참조 해제
// 문제: normalMap이 여전히 user 객체를 참조
// → user 객체는 GC 불가능
// → 메모리 누수!

// ✅ WeakMap: 자동 정리
const weakMap = new WeakMap();

function processUserFixed(user) {
  weakMap.set(user, {
    lastAccess: Date.now(),
    permissions: ['read', 'write']
  });
}

let user2 = { id: 2, name: 'Bob' };
processUserFixed(user2);

user2 = null;  // user2 참조 해제
// weakMap의 항목도 자동으로 GC됨!
// → 메모리 누수 없음
```

#### 실전 사용 예: 캐싱

```javascript
// DOM 요소에 메타데이터 저장 (브라우저 환경)
class ComponentManager {
  constructor() {
    // WeakMap 사용: DOM이 제거되면 자동으로 정리됨
    this.componentData = new WeakMap();
  }

  mount(element, component) {
    this.componentData.set(element, {
      component,
      mountedAt: Date.now(),
      props: component.props
    });
  }

  unmount(element) {
    // 명시적 제거 (선택사항)
    this.componentData.delete(element);

    // element가 DOM에서 제거되면
    // componentData도 자동으로 GC됨
  }

  getData(element) {
    return this.componentData.get(element);
  }
}

// 사용
const manager = new ComponentManager();
const div = document.createElement('div');

manager.mount(div, { props: { text: 'Hello' } });

// div가 DOM에서 제거되고 참조가 사라지면
document.body.removeChild(div);
// → WeakMap의 항목도 자동으로 GC됨
```

#### Node.js에서의 WeakMap 활용

```javascript
// 객체에 Private 데이터 저장
const privateData = new WeakMap();

class BankAccount {
  constructor(balance) {
    // private 데이터를 WeakMap에 저장
    privateData.set(this, {
      balance,
      transactions: []
    });
  }

  deposit(amount) {
    const data = privateData.get(this);
    data.balance += amount;
    data.transactions.push({ type: 'deposit', amount });
  }

  getBalance() {
    return privateData.get(this).balance;
  }
}

let account = new BankAccount(1000);
console.log(account.getBalance());  // 1000

// account 객체가 제거되면
account = null;
// → privateData의 항목도 자동으로 GC됨
```

### 6.4 명시적 null 할당

#### 왜 필요한가?

함수 내에서 큰 객체를 사용한 후에도 함수가 계속 실행되면, 해당 객체는 함수가 끝날 때까지 메모리에 남습니다. **명시적으로 null을 할당**하면 GC가 더 빨리 회수할 수 있습니다.

```javascript
// ❌ 나쁜 예
async function processLargeData() {
  // 1. 큰 데이터 로드 (100MB)
  const hugeData = await loadHugeDataset();

  // 2. 데이터 처리
  const summary = computeSummary(hugeData);

  // 3. 오래 걸리는 다른 작업들
  await sendNotifications();       // 5초
  await updateDatabase(summary);   // 3초
  await generateReport();          // 10초

  // 문제: hugeData는 함수 끝까지 메모리 점유 (18초 동안!)
  // → 100MB가 불필요하게 메모리에 남음

  return summary;
}

// ✅ 좋은 예
async function processLargeDataFixed() {
  // 1. 큰 데이터 로드
  let hugeData = await loadHugeDataset();  // let 사용!

  // 2. 데이터 처리
  const summary = computeSummary(hugeData);

  // 3. 명시적으로 참조 해제
  hugeData = null;  // 즉시 GC 대상이 됨!

  // 4. 다른 작업들
  await sendNotifications();
  await updateDatabase(summary);
  await generateReport();

  // hugeData는 이미 GC되어 메모리 절약

  return summary;
}
```

#### 배열 정리

```javascript
// 배열 완전히 비우기
let largeArray = new Array(1000000).fill('data');

// ❌ 나쁜 예
largeArray = [];  // 새 배열 생성, 기존 배열은 GC 대기

// ✅ 좋은 예 1: length = 0
largeArray.length = 0;  // 기존 배열을 비움 (더 효율적)

// ✅ 좋은 예 2: null 할당
largeArray = null;  // 명시적 해제
```

#### 클로저에서의 명시적 해제

```javascript
function createDataProcessor() {
  let cache = new Map();
  let largeConfig = loadConfiguration();  // 10MB

  // 초기화 후 largeConfig는 필요 없음
  const processor = {
    process: (data) => {
      // largeConfig를 사용하지 않음
      cache.set(data.id, data);
    },

    cleanup: () => {
      cache.clear();
      cache = null;
    }
  };

  // largeConfig 해제
  largeConfig = null;

  return processor;
}
```

---

## 7. 실전 메모리 디버깅 워크플로우

### 7.1 메모리 누수 감지

#### node-memwatch 사용

```javascript
const memwatch = require('@airbnb/node-memwatch');

// 1. 메모리 누수 자동 감지
memwatch.on('leak', (info) => {
  console.error('━━━ 메모리 누수 감지! ━━━');
  console.error('증가량:', info.growth);
  console.error('이유:', info.reason);

  // 힙 스냅샷 자동 저장
  const filename = `./leaks/leak-${Date.now()}.heapsnapshot`;
  require('v8').writeHeapSnapshot(filename);
  console.error('스냅샷 저장:', filename);
});

// 2. GC 통계 모니터링
memwatch.on('stats', (stats) => {
  const heapDiff = stats.current_base - stats.estimated_base;

  console.log('━━━ GC 통계 ━━━');
  console.log('GC 타입:', stats.usage_trend === 'GROWING' ? '⚠️ 증가 중' : '✓ 안정');
  console.log('Heap 사용량:', {
    before: `${Math.round(stats.before / 1024 / 1024)} MB`,
    after: `${Math.round(stats.after / 1024 / 1024)} MB`,
    diff: `${Math.round(heapDiff / 1024 / 1024)} MB`
  });
  console.log('GC 소요시간:', `${stats.duration}ms`);
});

// 3. Heap Diff로 메모리 변화 추적
const hd = new memwatch.HeapDiff();

// ... 의심되는 작업 실행 ...

const diff = hd.end();

console.log('━━━ Heap Diff 결과 ━━━');
diff.change.details.forEach(detail => {
  if (detail.size_bytes > 1000000) {  // 1MB 이상 증가한 항목만
    console.log(`${detail.what}: ${Math.round(detail.size_bytes / 1024 / 1024)}MB (${detail['+']} 증가)`);
  }
});
```

### 7.2 프로파일링 도구

#### Chrome DevTools 프로파일링

```bash
# 1. Inspector 모드로 Node.js 실행
node --inspect app.js

# 또는 특정 포트 지정
node --inspect=0.0.0.0:9229 app.js

# 2. Chrome 브라우저에서 접속
# chrome://inspect

# 3. "Open dedicated DevTools for Node" 클릭

# 4. Memory 탭에서:
#    - Heap Snapshot: 현재 메모리 상태 스냅샷
#    - Allocation instrumentation: 시간에 따른 메모리 할당 추적
#    - Allocation sampling: 샘플링 방식으로 할당 추적
```

#### Clinic.js 종합 분석

```bash
# Clinic.js 설치
npm install -g clinic

# 1. Doctor: 종합 성능 분석
clinic doctor -- node app.js
# 결과: CPU, 메모리, 이벤트 루프 지연 등 종합 분석
# HTML 리포트 자동 생성

# 2. BubbleProf: 비동기 작업 시각화
clinic bubbleprof -- node app.js
# 결과: 비동기 작업의 관계와 지연 시각화

# 3. Flame: CPU 프로파일링
clinic flame -- node app.js
# 결과: 함수 호출 스택과 CPU 사용 시각화

# 4. HeapProfiler: 메모리 할당 분석
clinic heapprofiler -- node app.js
# 결과: 시간에 따른 메모리 할당 추적
```

#### 종합 디버깅 스크립트

```javascript
// debug-memory.js
const v8 = require('v8');
const fs = require('fs');
const path = require('path');

class MemoryDebugger {
  constructor(options = {}) {
    this.snapshotDir = options.snapshotDir || './memory-snapshots';
    this.logDir = options.logDir || './memory-logs';
    this.interval = options.interval || 10000;

    // 디렉토리 생성
    [this.snapshotDir, this.logDir].forEach(dir => {
      if (!fs.existsSync(dir)) {
        fs.mkdirSync(dir, { recursive: true });
      }
    });

    this.baseline = null;
    this.snapshots = [];
  }

  start() {
    console.log('메모리 디버깅 시작...');

    // 1. 초기 스냅샷
    this.takeSnapshot('baseline');
    this.baseline = process.memoryUsage();

    // 2. 주기적 모니터링
    this.monitoringId = setInterval(() => {
      this.checkMemory();
    }, this.interval);

    // 3. 프로세스 종료 시 최종 스냅샷
    process.on('SIGINT', () => {
      this.stop();
    });
  }

  checkMemory() {
    const current = process.memoryUsage();
    const growth = {
      heapUsed: current.heapUsed - this.baseline.heapUsed,
      rss: current.rss - this.baseline.rss
    };

    const growthMB = {
      heapUsed: Math.round(growth.heapUsed / 1024 / 1024),
      rss: Math.round(growth.rss / 1024 / 1024)
    };

    // 로그 저장
    const logEntry = {
      timestamp: new Date().toISOString(),
      current: {
        heapUsed: Math.round(current.heapUsed / 1024 / 1024),
        heapTotal: Math.round(current.heapTotal / 1024 / 1024),
        rss: Math.round(current.rss / 1024 / 1024)
      },
      growth: growthMB
    };

    this.writeLog(logEntry);

    // 경고 조건
    if (growthMB.heapUsed > 100) {  // 100MB 이상 증가
      console.warn(`⚠️ 큰 메모리 증가 감지: ${growthMB.heapUsed}MB`);
      this.takeSnapshot(`growth-${Date.now()}`);
    }
  }

  takeSnapshot(label) {
    const filename = path.join(
      this.snapshotDir,
      `${label}-${Date.now()}.heapsnapshot`
    );

    console.log(`스냅샷 생성: ${filename}`);
    v8.writeHeapSnapshot(filename);

    this.snapshots.push({
      label,
      filename,
      timestamp: Date.now()
    });
  }

  writeLog(entry) {
    const logFile = path.join(
      this.logDir,
      `memory-${new Date().toISOString().split('T')[0]}.jsonl`
    );

    fs.appendFileSync(logFile, JSON.stringify(entry) + '\n');
  }

  stop() {
    console.log('\n메모리 디버깅 중지...');

    if (this.monitoringId) {
      clearInterval(this.monitoringId);
    }

    // 최종 스냅샷
    this.takeSnapshot('final');

    // 리포트 생성
    this.generateReport();

    process.exit(0);
  }

  generateReport() {
    console.log('\n━━━ 메모리 디버깅 리포트 ━━━');
    console.log(`스냅샷 개수: ${this.snapshots.length}`);

    this.snapshots.forEach((snapshot, i) => {
      console.log(`${i + 1}. ${snapshot.label}`);
      console.log(`   파일: ${snapshot.filename}`);
    });

    console.log('\n비교 방법:');
    console.log('1. Chrome DevTools 열기 (chrome://inspect)');
    console.log('2. Memory 탭 → Load 버튼');
    console.log('3. baseline 스냅샷 로드');
    console.log('4. final 스냅샷 로드');
    console.log('5. Comparison 뷰로 비교');
  }
}

// 사용
if (require.main === module) {
  const debugger = new MemoryDebugger({
    interval: 5000  // 5초마다 체크
  });

  debugger.start();

  // 실제 앱 실행
  require('./app.js');
}

module.exports = MemoryDebugger;
```

---

## 8. 체크리스트

### 개발 시 체크사항

- [ ] **전역 변수 최소화**: 불필요한 전역 변수는 메모리 누수의 주범
- [ ] **이벤트 리스너 정리**: `removeListener`, `removeAllListeners` 호출
- [ ] **타이머 정리**: `clearInterval`, `clearTimeout` 반드시 호출
- [ ] **클로저 주의**: 큰 객체를 클로저에서 참조하지 않도록 주의
- [ ] **스트림 사용**: 대용량 파일/데이터는 스트림으로 처리
- [ ] **WeakMap/WeakSet 고려**: 캐싱 시 자동 정리되도록
- [ ] **순환 참조 방지**: 객체 간 순환 참조는 메모리 누수 원인
- [ ] **명시적 null 할당**: 큰 객체 사용 후 즉시 null 할당

### 프로덕션 배포 전 체크사항

- [ ] **메모리 프로파일링**: 실제 부하 상황에서 메모리 사용 패턴 분석
- [ ] **부하 테스트**: 장시간 실행 테스트로 메모리 누수 확인
- [ ] **힙 크기 설정**: `--max-old-space-size` 적절히 설정
- [ ] **모니터링 설정**: 프로덕션 메모리 모니터링 도구 설정
- [ ] **알림 임계값**: 메모리 사용량 알림 임계값 설정
- [ ] **로그 수집**: GC 로그, 메모리 사용량 로그 수집 설정
- [ ] **재시작 정책**: OOM 발생 시 자동 재시작 정책 수립

---

## 9. 유용한 도구

### 프로파일링 & 디버깅
- **Chrome DevTools**: 힙 스냅샷, 타임라인 프로파일링
- **Clinic.js**: 종합 성능 분석 (Doctor, Flame, BubbleProf, HeapProfiler)
- **node-memwatch**: 메모리 누수 자동 감지
- **heapdump**: 프로그래밍 방식으로 힙 덤프 생성

### 모니터링
- **PM2**: 프로세스 관리 및 메모리 모니터링
- **New Relic**: APM 도구, 실시간 메모리 모니터링
- **Datadog**: 인프라 및 애플리케이션 모니터링
- **Prometheus + Grafana**: 커스텀 메모리 메트릭 수집 및 시각화

---

## 10. 참고 자료

- [V8 공식 문서 - Trash Talk](https://v8.dev/blog/trash-talk): V8 GC 동작 원리
- [Node.js 메모리 관리 가이드](https://nodejs.org/en/docs/guides/simple-profiling/): 공식 프로파일링 가이드
- [메모리 누수 디버깅](https://nodejs.org/en/docs/guides/diagnostics/memory/): Node.js 공식 진단 가이드
- [Understanding Garbage Collection](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Memory_Management): MDN 메모리 관리 문서
