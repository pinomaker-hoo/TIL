# Node.js 메모리 기초

> Node.js에서 메모리가 어떻게 동작하는지, 왜 메모리 누수가 발생하는지, 어떻게 해결할 수 있는지에 대한 핵심 개념 정리

## 목차
1. [메모리 구조 이해하기](#1-메모리-구조-이해하기)
2. [메모리는 언제 할당되고 해제되나?](#2-메모리는-언제-할당되고-해제되나)
3. [가비지 컬렉션이 작동하는 방식](#3-가비지-컬렉션이-작동하는-방식)
4. [메모리 누수가 발생하는 5가지 패턴](#4-메모리-누수가-발생하는-5가지-패턴)
5. [메모리 문제 진단하기](#5-메모리-문제-진단하기)
6. [실전 메모리 최적화 팁](#6-실전-메모리-최적화-팁)

---

## 1. 메모리 구조 이해하기

### Node.js 메모리는 어떻게 구성되어 있나?

```javascript
const usage = process.memoryUsage();
console.log(usage);

/*
출력 예시:
{
  rss: 50331648,          // 50MB - 총 메모리 사용량
  heapTotal: 20971520,    // 21MB - V8이 할당한 힙
  heapUsed: 15728640,     // 15MB - 실제 사용 중인 힙
  external: 2097152,      // 2MB - C++ 객체 메모리
  arrayBuffers: 1048576   // 1MB - ArrayBuffer 메모리
}
*/
```

**각 항목의 의미:**

1. **RSS (Resident Set Size)**
   - 프로세스가 실제로 사용하는 **물리 메모리**
   - 힙 + 스택 + 코드 + 외부 라이브러리 모두 포함
   - 이 값이 계속 증가하면 메모리 누수 의심

2. **Heap Total vs Heap Used**
   - **heapTotal**: V8이 예약한 총 메모리 (아직 사용 안 한 공간 포함)
   - **heapUsed**: 실제로 객체들이 사용 중인 메모리
   - heapUsed가 heapTotal에 가까워지면 V8이 자동으로 heapTotal 확장

3. **External**
   - JavaScript가 아닌 **C++ 객체가 사용하는 메모리**
   - Buffer, fs 모듈 등에서 사용

4. **Array Buffers**
   - ArrayBuffer, SharedArrayBuffer가 사용하는 메모리

### 힙 메모리 내부 구조

```
V8 Heap Memory
├── New Space (1-8MB)
│   ├── From-space
│   └── To-space
│   → 새로 생성된 객체
│   → 빠른 GC (Scavenge)
│
├── Old Space (~1.4GB)
│   → 오래 살아남은 객체
│   → 느린 GC (Mark-Sweep)
│
├── Large Object Space
│   → 1MB 이상 큰 객체
│
└── Code Space
    → JIT 컴파일된 코드
```

**핵심 개념:**
- 대부분의 객체는 **New Space**에서 시작
- GC를 2번 이상 살아남으면 **Old Space**로 승격 (Promotion)
- Old Space의 기본 크기 제한: 1.4GB (64bit), 700MB (32bit)

---

## 2. 메모리는 언제 할당되고 해제되나?

### 메모리 할당 시점

```javascript
// 1. 변수 선언 시
const user = { name: 'Alice', age: 30 };  // 힙에 객체 할당

// 2. 배열 생성 시
const numbers = new Array(1000);  // 힙에 배열 할당

// 3. 함수 정의 시
function process() {
  // 함수 객체도 힙에 할당
  const temp = { data: 'temp' };  // 지역 변수도 힙에 할당
}

// 4. 클로저 생성 시
function outer() {
  const data = 'captured';  // 클로저에 의해 유지됨
  return function inner() {
    console.log(data);  // data를 참조
  };
}
const fn = outer();  // data는 계속 메모리에 유지
```

### 메모리 해제 시점

```javascript
// 기본 원칙: 더 이상 참조되지 않는 객체는 GC 대상

// 예시 1: 함수 종료 시
function processData() {
  const temp = new Array(10000);  // 힙에 할당
  return temp.length;
  // 함수 종료 → temp에 대한 참조 사라짐 → GC 대상
}

// 예시 2: 참조 해제 시
let user = { name: 'Bob' };  // 힙에 할당
user = null;  // 참조 해제 → GC 대상

// 예시 3: 스코프 벗어날 때
{
  const localData = { data: 'local' };  // 블록 스코프
}
// 블록 끝 → localData 접근 불가 → GC 대상

// ⚠️ 주의: 전역 변수는 프로그램 종료까지 유지
global.cache = [];  // 프로그램이 끝날 때까지 메모리 점유
```

**메모리 라이프사이클:**
```
할당 → 사용 → 참조 해제 → GC 대기 → 메모리 회수
```

---

## 3. 가비지 컬렉션이 작동하는 방식

### GC의 기본 원리

**도달 가능성(Reachability) 기반:**
- 루트(Root)에서 도달 가능한 객체 = 살아있는 객체
- 도달 불가능한 객체 = 가비지

```javascript
// 루트(Root)가 무엇인가?
// 1. 전역 객체 (global, window)
// 2. 현재 실행 중인 함수의 지역 변수
// 3. 호출 스택의 모든 변수

let obj1 = { data: 'A' };  // obj1 → Root에서 도달 가능
let obj2 = { data: 'B' };  // obj2 → Root에서 도달 가능

obj1.ref = obj2;  // obj1 → obj2 참조
obj2 = null;      // obj2 변수는 null

// 그런데 obj2 객체는 아직 살아있음!
// 왜? obj1.ref가 여전히 참조하고 있기 때문
console.log(obj1.ref.data);  // 'B' 출력

obj1 = null;  // 이제 obj2 객체도 GC 대상
              // 어디서도 참조하지 않음
```

### Scavenge GC (Minor GC) - 빠르고 자주 발생

**New Space에서 동작:**

```javascript
// 시나리오: API 요청 처리
function handleRequest(req) {
  // Step 1: 객체 생성 → New Space에 할당
  const requestData = {
    id: req.id,
    timestamp: Date.now(),
    body: req.body
  };

  // Step 2: 처리
  const result = processRequest(requestData);

  // Step 3: 응답 반환
  return result;

  // Step 4: 함수 종료
  // → requestData에 대한 참조 사라짐
  // → 다음 Scavenge GC에서 정리됨 (1~10ms)
}

// 1초에 100개 요청 → 100개 객체 생성 및 정리
// Scavenge GC가 자주 실행되지만, 매우 빠름
```

**Scavenge 동작 방식:**
```
From-space: [A][B][C][D][E]
                ↓ GC 실행
To-space:   [B][D]  ← 살아있는 것만 복사
                ↓
From-space와 To-space 교체
```

### Mark-Sweep GC (Major GC) - 느리고 덜 발생

**Old Space에서 동작:**

```javascript
// 시나리오: 캐시 데이터 관리
const cache = new Map();  // 전역 → Old Space에 할당

function addToCache(key, value) {
  cache.set(key, value);
  // cache는 전역이므로 계속 Old Space에 유지
}

function removeFromCache(key) {
  cache.delete(key);
  // 삭제된 value 객체는 Major GC에서 정리됨 (100ms~1s)
}

// 캐시에 10000개 추가
for (let i = 0; i < 10000; i++) {
  addToCache(i, { data: new Array(1000) });
}

// 5000개 제거
for (let i = 0; i < 5000; i++) {
  removeFromCache(i);
}

// 제거된 5000개 객체는 언제 정리될까?
// → Old Space가 가득 차면 Major GC 실행
// → 또는 일정 시간 후 자동 실행
```

**Mark-Sweep 3단계:**
```
1. Marking: 살아있는 객체 표시
   [✓A][ B][✓C][ D][✓E]

2. Sweeping: 표시 안 된 객체 제거
   [✓A][  ][✓C][  ][✓E]

3. Compaction: 메모리 정리 (필요 시)
   [✓A][✓C][✓E][─────빈 공간─────]
```

### GC가 실행되는 시점

```javascript
// GC는 언제 실행될까?

// 1. New Space가 가득 찰 때 → Scavenge
//    (매우 자주, 1초에 수십 번 가능)

// 2. Old Space가 임계값에 도달했을 때 → Mark-Sweep
//    (덜 자주, 수 초~수 분에 한 번)

// 3. 메모리 압박 상황 → 강제 GC
//    (힙이 한계에 가까워지면)

// 수동 GC 트리거 (디버깅용, 프로덕션 비권장)
if (global.gc) {
  global.gc();  // --expose-gc 플래그 필요
}
```

---

## 4. 메모리 누수가 발생하는 5가지 패턴

### 패턴 1: 전역 변수에 계속 추가

```javascript
// ❌ 문제 코드
const logs = [];  // 전역 변수

setInterval(() => {
  logs.push({
    timestamp: Date.now(),
    message: 'Log entry',
    data: new Array(1000).fill('data')
  });
  // logs는 계속 커짐, GC 불가능
}, 100);

// 1분 후: 600개 × ~8KB = 4.8MB
// 1시간 후: 36000개 × ~8KB = 288MB
// 24시간 후: 864000개 × ~8KB = 6.9GB → 💥 크래시

// ✅ 해결: 크기 제한
const MAX_LOGS = 1000;
const logs = [];

setInterval(() => {
  if (logs.length >= MAX_LOGS) {
    logs.shift();  // 가장 오래된 것 제거
  }
  logs.push({
    timestamp: Date.now(),
    message: 'Log entry'
  });
}, 100);

// 메모리 사용: 최대 1000개 × ~8KB = 8MB로 고정
```

### 패턴 2: 이벤트 리스너 미제거

```javascript
const EventEmitter = require('events');
const emitter = new EventEmitter();

// ❌ 문제 코드
function startMonitoring(userId) {
  const userData = loadUserData(userId);  // 큰 객체

  // 리스너 등록
  emitter.on('update', () => {
    processUserData(userData);  // userData를 클로저로 참조
  });

  // 사용자 로그아웃해도 리스너는 계속 유지
  // → userData도 계속 메모리에 유지
}

// 1000명 로그인 → 1000개 리스너 + userData
// 메모리 누수!

// ✅ 해결: 리스너 제거
function startMonitoring(userId) {
  const userData = loadUserData(userId);

  const updateListener = () => {
    processUserData(userData);
  };

  emitter.on('update', updateListener);

  // 정리 함수 반환
  return () => {
    emitter.removeListener('update', updateListener);
    // userData도 이제 GC 대상
  };
}

const cleanup = startMonitoring(123);
// 로그아웃 시
cleanup();
```

### 패턴 3: 타이머 미정리

```javascript
// ❌ 문제 코드
class DataFetcher {
  constructor(url) {
    this.url = url;
    this.data = [];

    // 타이머 시작
    setInterval(() => {
      this.fetch();
    }, 1000);
  }

  fetch() {
    // API 호출
    this.data.push(fetchData(this.url));
  }
}

let fetcher = new DataFetcher('http://api.example.com');

// fetcher를 null로 설정해도...
fetcher = null;
// setInterval은 계속 실행!
// DataFetcher 인스턴스도 GC 불가능!

// ✅ 해결: 타이머 정리
class DataFetcher {
  constructor(url) {
    this.url = url;
    this.data = [];
    this.intervalId = null;
  }

  start() {
    this.intervalId = setInterval(() => {
      this.fetch();
    }, 1000);
  }

  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  fetch() {
    this.data.push(fetchData(this.url));
  }
}

const fetcher = new DataFetcher('http://api.example.com');
fetcher.start();

// 정리
fetcher.stop();
// 이제 fetcher는 GC 가능
```

### 패턴 4: 클로저의 의도치 않은 참조

```javascript
// ❌ 문제 코드
function createProcessor() {
  // 매우 큰 데이터
  const hugeData = new Array(1000000).fill('data');  // ~8MB

  // 작은 함수만 반환하는데...
  return function process(id) {
    console.log(`Processing ${id}`);
    // hugeData를 사용하지 않지만...
  };
}

const processor = createProcessor();
// 문제: hugeData가 클로저에 의해 계속 메모리에 유지됨!

// ✅ 해결 1: 필요한 것만 추출
function createProcessor() {
  const hugeData = new Array(1000000).fill('data');

  // 필요한 것만 추출
  const summary = {
    length: hugeData.length,
    firstItem: hugeData[0]
  };

  // hugeData는 여기서 GC 대상

  return function process(id) {
    console.log(`Processing ${id}, length: ${summary.length}`);
  };
}

// ✅ 해결 2: 명시적 null 할당
function createProcessor() {
  let hugeData = new Array(1000000).fill('data');

  const summary = computeSummary(hugeData);
  hugeData = null;  // 명시적으로 해제

  return function process(id) {
    console.log(`Processing ${id}`, summary);
  };
}
```

### 패턴 5: 순환 참조

```javascript
// ❌ 문제 코드
class Node {
  constructor(value) {
    this.value = value;
    this.parent = null;
    this.children = [];
  }

  addChild(child) {
    child.parent = this;  // 자식 → 부모
    this.children.push(child);  // 부모 → 자식
    // 순환 참조 발생
  }
}

let root = new Node('root');
let child1 = new Node('child1');
root.addChild(child1);

root = null;
child1 = null;

// 순환 참조가 있어도 현대 GC는 정리 가능
// 하지만 JSON.stringify 같은 곳에서 문제 발생 가능

// ✅ 해결: WeakMap 사용
const parents = new WeakMap();

class Node {
  constructor(value) {
    this.value = value;
    this.children = [];
  }

  addChild(child) {
    parents.set(child, this);  // WeakMap 사용
    this.children.push(child);
  }

  getParent() {
    return parents.get(this);
  }
}

// Node가 GC되면 WeakMap 항목도 자동 정리
```

---

## 5. 메모리 문제 진단하기

### 증상별 진단 방법

#### 증상 1: 메모리가 계속 증가

```javascript
// 진단 스크립트
let baseline = process.memoryUsage().heapUsed;

setInterval(() => {
  const current = process.memoryUsage().heapUsed;
  const diff = current - baseline;
  const diffMB = (diff / 1024 / 1024).toFixed(2);

  console.log(`메모리 증가: ${diffMB}MB`);

  if (diff > 100 * 1024 * 1024) {  // 100MB 이상 증가
    console.error('⚠️ 메모리 누수 의심!');

    // 힙 스냅샷 저장
    const v8 = require('v8');
    v8.writeHeapSnapshot(`./leak-${Date.now()}.heapsnapshot`);
  }
}, 5000);
```

#### 증상 2: GC가 너무 자주 발생

```bash
# GC 로그 활성화
node --trace-gc app.js

# 출력 예시:
# [GC] Scavenge 2.1 (4.0) -> 1.8 (5.0) MB, 1.2ms
# [GC] Scavenge 2.5 (5.0) -> 2.1 (6.0) MB, 1.5ms
# [GC] Mark-sweep 15.2 (20.0) -> 12.3 (18.0) MB, 145ms

# Scavenge가 초당 수십 번 → 객체 생성이 너무 많음
# Mark-sweep이 자주 발생 → Old Space 압박
```

#### 증상 3: "Out of Memory" 에러

```javascript
// FATAL ERROR: CALL_AND_RETRY_LAST Allocation failed
// JavaScript heap out of memory

// 원인:
// 1. 힙 크기 제한 도달 (기본 ~1.4GB)
// 2. 메모리 누수로 인한 과도한 메모리 사용

// 임시 해결: 힙 크기 늘리기
// node --max-old-space-size=4096 app.js  // 4GB

// 근본 해결: 메모리 누수 제거 또는 스트림 사용
```

### 메모리 프로파일링 도구

#### 1. Chrome DevTools

```bash
# 1. Node.js를 inspect 모드로 실행
node --inspect app.js

# 2. Chrome에서 chrome://inspect 접속

# 3. Memory 탭에서:
# - Heap Snapshot: 현재 메모리 상태
# - Allocation instrumentation: 시간에 따른 할당 추적
```

#### 2. process.memoryUsage() 모니터링

```javascript
// 간단한 모니터링
class MemoryMonitor {
  constructor() {
    this.history = [];
  }

  start(interval = 5000) {
    setInterval(() => {
      const usage = process.memoryUsage();

      this.history.push({
        timestamp: Date.now(),
        heapUsed: usage.heapUsed,
        rss: usage.rss
      });

      // 최근 10개만 유지
      if (this.history.length > 10) {
        this.history.shift();
      }

      // 증가 추세 체크
      if (this.history.length >= 5) {
        const recent = this.history.slice(-5);
        const isIncreasing = recent.every((item, i) => {
          if (i === 0) return true;
          return item.heapUsed >= recent[i - 1].heapUsed;
        });

        if (isIncreasing) {
          console.warn('⚠️ 메모리 지속 증가 감지!');
          this.printStats();
        }
      }
    }, interval);
  }

  printStats() {
    const latest = this.history[this.history.length - 1];
    const oldest = this.history[0];

    const growth = latest.heapUsed - oldest.heapUsed;
    const growthMB = (growth / 1024 / 1024).toFixed(2);
    const duration = (latest.timestamp - oldest.timestamp) / 1000;

    console.log(`메모리 증가: ${growthMB}MB (${duration}초 동안)`);
  }
}

const monitor = new MemoryMonitor();
monitor.start();
```

---

## 6. 실전 메모리 최적화 팁

### Tip 1: 스트림으로 대용량 파일 처리

```javascript
const fs = require('fs');

// ❌ 나쁜 예: 전체 파일을 메모리에 로드
async function processLargeFile() {
  const data = await fs.promises.readFile('10GB-file.txt');
  // 10GB 메모리 사용! → 💥
  return processData(data);
}

// ✅ 좋은 예: 스트림 사용
function processLargeFile() {
  return new Promise((resolve, reject) => {
    let result = 0;

    const stream = fs.createReadStream('10GB-file.txt', {
      highWaterMark: 64 * 1024  // 64KB씩 읽기
    });

    stream.on('data', (chunk) => {
      result += processChunk(chunk);
      // 청크 처리 후 메모리 해제
    });

    stream.on('end', () => resolve(result));
    stream.on('error', reject);
  });
}

// 메모리 사용: 최대 64KB만 사용!
```

### Tip 2: 객체 풀링으로 GC 압력 감소

```javascript
// 고빈도 객체 생성 시나리오
// ❌ 나쁜 예: 매번 새로 생성
function handleRequest() {
  const buffer = Buffer.alloc(1024);  // 매번 새로 할당
  // 사용
  return processBuffer(buffer);
  // buffer GC 대상 → GC 압력 증가
}

// 1초에 1000개 요청 → 1000개 Buffer 생성 및 GC

// ✅ 좋은 예: 객체 풀 사용
class BufferPool {
  constructor(size = 100, bufferSize = 1024) {
    this.pool = [];
    for (let i = 0; i < size; i++) {
      this.pool.push(Buffer.alloc(bufferSize));
    }
  }

  acquire() {
    return this.pool.pop() || Buffer.alloc(1024);
  }

  release(buffer) {
    buffer.fill(0);  // 초기화
    if (this.pool.length < 100) {
      this.pool.push(buffer);
    }
  }
}

const pool = new BufferPool();

function handleRequest() {
  const buffer = pool.acquire();  // 풀에서 가져오기
  const result = processBuffer(buffer);
  pool.release(buffer);  // 풀에 반환
  return result;
}

// 100개 Buffer만 생성, 계속 재사용 → GC 거의 없음
```

### Tip 3: WeakMap으로 자동 메모리 정리

```javascript
// 시나리오: 임시 객체에 메타데이터 추가

// ❌ 나쁜 예: 일반 Map 사용
const metadata = new Map();

function processUser(user) {
  metadata.set(user, {
    processedAt: Date.now(),
    flags: ['processed']
  });

  doSomething(user);
}

let user = { id: 1 };
processUser(user);

user = null;  // user 참조 해제
// 문제: metadata가 여전히 user를 참조
// → user 객체 GC 불가능!

// ✅ 좋은 예: WeakMap 사용
const metadata = new WeakMap();

function processUser(user) {
  metadata.set(user, {
    processedAt: Date.now(),
    flags: ['processed']
  });

  doSomething(user);
}

let user = { id: 1 };
processUser(user);

user = null;  // user 참조 해제
// WeakMap의 항목도 자동으로 GC됨!
```

### Tip 4: 배치 처리로 메모리 사용 분산

```javascript
// 시나리오: 대량 데이터 처리

// ❌ 나쁜 예: 한 번에 모두 처리
async function processAllUsers(users) {
  const results = await Promise.all(
    users.map(user => processUser(user))
  );
  // 10000개 user를 동시에 메모리에 로드!
  return results;
}

// ✅ 좋은 예: 배치 처리
async function processAllUsers(users, batchSize = 100) {
  const results = [];

  for (let i = 0; i < users.length; i += batchSize) {
    const batch = users.slice(i, i + batchSize);

    // 100개씩 처리
    const batchResults = await Promise.all(
      batch.map(user => processUser(user))
    );

    results.push(...batchResults);

    // 이전 배치는 GC 가능
    console.log(`Processed ${i + batchSize}/${users.length}`);
  }

  return results;
}

// 메모리: 최대 100개 user만 동시 처리
```

### Tip 5: 명시적 null 할당

```javascript
// 큰 객체를 일찍 해제하기

async function processData() {
  // 1. 큰 데이터 로드
  let largeData = await loadLargeDataset();  // 500MB

  // 2. 요약 생성
  const summary = computeSummary(largeData);  // 1MB

  // 3. 명시적 해제
  largeData = null;  // 즉시 GC 대상
  // 500MB 메모리 회수 가능

  // 4. 오래 걸리는 다른 작업
  await sendNotifications(summary);  // 10초
  await saveToDatabase(summary);     // 5초

  // largeData 없이 진행 → 메모리 효율적!
  return summary;
}
```

---

## 핵심 요약

### 메모리 관리 체크리스트

**개발 시:**
- [ ] 전역 변수 최소화
- [ ] 이벤트 리스너 반드시 제거
- [ ] 타이머 (setInterval, setTimeout) 정리
- [ ] 큰 데이터는 스트림으로 처리
- [ ] 클로저에서 불필요한 참조 제거

**디버깅 시:**
- [ ] `process.memoryUsage()` 모니터링
- [ ] `--trace-gc`로 GC 로그 확인
- [ ] 힙 스냅샷으로 메모리 누수 찾기
- [ ] 메모리 증가 패턴 분석

**프로덕션 배포 전:**
- [ ] 부하 테스트로 메모리 누수 확인
- [ ] 적절한 힙 크기 설정 (`--max-old-space-size`)
- [ ] 메모리 모니터링 설정
- [ ] 알림 임계값 설정

### 메모리 문제 해결 흐름

```
1. 증상 확인
   ↓
2. 메모리 사용량 모니터링
   ↓
3. 힙 스냅샷 비교
   ↓
4. 메모리 누수 패턴 식별
   ↓
5. 코드 수정
   ↓
6. 부하 테스트로 검증
```

### 유용한 명령어

```bash
# 메모리 사용량 체크
node -e "console.log(process.memoryUsage())"

# GC 로그 활성화
node --trace-gc app.js

# 힙 크기 늘리기 (4GB)
node --max-old-space-size=4096 app.js

# Inspector 모드
node --inspect app.js

# 강제 GC 허용 (디버깅용)
node --expose-gc app.js
```

---

## 참고 자료

- [Node.js 메모리 관리 공식 문서](https://nodejs.org/en/docs/guides/simple-profiling/)
- [V8 가비지 컬렉션](https://v8.dev/blog/trash-talk)
- [Chrome DevTools Memory Profiling](https://developer.chrome.com/docs/devtools/memory-problems/)
