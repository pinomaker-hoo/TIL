# Node.js GC와 메모리 관리

## 1. V8 엔진과 메모리 구조

Node.js는 V8 JavaScript 엔진을 사용하며, V8은 메모리를 다음과 같이 구조화합니다:

### 메모리 영역

```
┌─────────────────────────────┐
│     Resident Set (RSS)      │
├─────────────────────────────┤
│                             │
│  ┌─────────────────────┐   │
│  │   Heap Memory       │   │
│  ├─────────────────────┤   │
│  │   New Space         │   │ ← 젊은 세대 (Young Generation)
│  │   - Semi-space 0    │   │
│  │   - Semi-space 1    │   │
│  ├─────────────────────┤   │
│  │   Old Space         │   │ ← 오래된 세대 (Old Generation)
│  ├─────────────────────┤   │
│  │   Large Object      │   │
│  │   Space             │   │
│  ├─────────────────────┤   │
│  │   Code Space        │   │
│  └─────────────────────┘   │
│                             │
│  ┌─────────────────────┐   │
│  │   Stack             │   │
│  └─────────────────────┘   │
└─────────────────────────────┘
```

#### Heap 영역 상세

1. **New Space (Young Generation)**
   - 크기: 기본 1~8MB (--max-semi-space-size로 조정)
   - 새로 생성된 객체가 할당되는 공간
   - Semi-space 2개로 구성 (From-space, To-space)
   - Scavenge GC 알고리즘 사용

2. **Old Space (Old Generation)**
   - 크기: 기본 ~1.4GB (64bit), ~700MB (32bit)
   - New Space에서 살아남은 객체들이 이동
   - Mark-Sweep & Mark-Compact 알고리즘 사용

3. **Large Object Space**
   - 큰 객체들을 위한 공간 (약 1MB 이상)
   - GC 대상이 아님

4. **Code Space**
   - JIT 컴파일된 코드 저장

## 2. Garbage Collection 알고리즘

### 2.1 Scavenge (Minor GC)

**New Space에서 동작하는 빠른 GC**

```javascript
// Scavenge 동작 원리
/*
1. From-space의 살아있는 객체를 To-space로 복사
2. From-space와 To-space를 교체
3. 2번 이상 살아남은 객체는 Old Space로 승격 (Promotion)
*/

// 예제: 짧은 생명주기 객체
function processRequest(req) {
  const tempData = { ...req.body }; // New Space에 할당
  const result = transform(tempData);
  return result;
  // tempData는 함수 종료 후 Scavenge GC 대상
}
```

**특징:**
- 매우 빠름 (1~10ms)
- 자주 발생
- Stop-the-World (애플리케이션 일시 중지)

### 2.2 Mark-Sweep (Major GC)

**Old Space에서 동작하는 주요 GC**

```javascript
// Mark-Sweep 과정
/*
Phase 1: Marking (표시)
  - 루트(전역 객체, 실행 컨텍스트)부터 시작
  - 도달 가능한 모든 객체 마킹

Phase 2: Sweeping (제거)
  - 마킹되지 않은 객체 제거
  - 메모리 해제

Phase 3: Compaction (압축) - 필요시
  - 메모리 조각화 해결
  - 객체를 연속된 메모리로 이동
*/

// 예제: 긴 생명주기 객체
const globalCache = new Map(); // Old Space에 할당

function cacheData(key, value) {
  globalCache.set(key, value);
  // globalCache는 루트에서 도달 가능 → GC 대상 아님
}
```

**특징:**
- 느림 (100ms~1s 이상)
- 덜 자주 발생
- Incremental/Concurrent 방식으로 최적화

### 2.3 Incremental Marking

```javascript
// 전통적 Mark-Sweep의 문제점
// - 큰 힙에서 마킹 시간이 오래 걸림 (Stop-the-World)
// - 애플리케이션 멈춤 현상 발생

// Incremental Marking 해결책
/*
1. 마킹 작업을 여러 단계로 분할
2. 각 단계 사이에 애플리케이션 실행
3. 전체 중지 시간 감소

Timeline:
[Mark] → [App] → [Mark] → [App] → [Mark] → [Sweep]
  5ms     10ms     5ms     10ms     5ms      10ms
*/
```

## 3. 메모리 누수 패턴과 해결법

### 3.1 전역 변수 누수

```javascript
// ❌ 나쁜 예
let leakyArray = [];

function processData(data) {
  leakyArray.push(data); // 계속 누적됨
}

// ✅ 좋은 예
function processData(data) {
  const localArray = [];
  localArray.push(data);
  return localArray;
  // 함수 종료 후 GC 대상
}
```

### 3.2 클로저 메모리 누수

```javascript
// ❌ 나쁜 예
function createHandler() {
  const hugeData = new Array(1000000).fill('data');

  return function handler() {
    console.log('Handler called');
    // hugeData는 사용되지 않지만 클로저에 의해 참조됨
  };
}

// ✅ 좋은 예
function createHandler() {
  const hugeData = new Array(1000000).fill('data');
  const needed = hugeData[0]; // 필요한 것만 추출

  return function handler() {
    console.log('Handler called:', needed);
    // hugeData는 GC 대상
  };
}
```

### 3.3 이벤트 리스너 누수

```javascript
// ❌ 나쁜 예
const EventEmitter = require('events');
const emitter = new EventEmitter();

function setupListener() {
  const largeBuffer = Buffer.alloc(1024 * 1024); // 1MB

  emitter.on('event', () => {
    console.log(largeBuffer.length);
  });
  // removeListener 하지 않으면 largeBuffer 계속 메모리 점유
}

// ✅ 좋은 예
function setupListener() {
  const largeBuffer = Buffer.alloc(1024 * 1024);

  const listener = () => {
    console.log(largeBuffer.length);
  };

  emitter.on('event', listener);

  // 정리 함수 반환
  return () => {
    emitter.removeListener('event', listener);
  };
}

const cleanup = setupListener();
// 사용 후
cleanup();
```

### 3.4 타이머 누수

```javascript
// ❌ 나쁜 예
function startPolling() {
  const cache = new Map();

  setInterval(() => {
    cache.set(Date.now(), fetchData());
    // cache가 계속 커짐
  }, 1000);
}

// ✅ 좋은 예
function startPolling() {
  const cache = new Map();
  const MAX_SIZE = 100;

  const intervalId = setInterval(() => {
    // 오래된 항목 제거
    if (cache.size >= MAX_SIZE) {
      const oldestKey = cache.keys().next().value;
      cache.delete(oldestKey);
    }
    cache.set(Date.now(), fetchData());
  }, 1000);

  // 정리 함수
  return () => {
    clearInterval(intervalId);
    cache.clear();
  };
}
```

## 4. 메모리 모니터링

### 4.1 process.memoryUsage()

```javascript
function checkMemory() {
  const usage = process.memoryUsage();

  console.log({
    // RSS: Resident Set Size - 프로세스가 사용하는 총 메모리
    rss: `${Math.round(usage.rss / 1024 / 1024)} MB`,

    // Heap Total: 할당된 총 힙 메모리
    heapTotal: `${Math.round(usage.heapTotal / 1024 / 1024)} MB`,

    // Heap Used: 실제 사용 중인 힙 메모리
    heapUsed: `${Math.round(usage.heapUsed / 1024 / 1024)} MB`,

    // External: C++ 객체에 바인딩된 메모리
    external: `${Math.round(usage.external / 1024 / 1024)} MB`,

    // Array Buffers: ArrayBuffer와 SharedArrayBuffer
    arrayBuffers: `${Math.round(usage.arrayBuffers / 1024 / 1024)} MB`
  });
}

// 주기적으로 체크
setInterval(checkMemory, 5000);
```

### 4.2 Heap Snapshot

```javascript
const v8 = require('v8');
const fs = require('fs');

// 힙 스냅샷 생성
function takeHeapSnapshot(filename) {
  const snapshotStream = v8.writeHeapSnapshot(filename);
  console.log(`Heap snapshot written to ${snapshotStream}`);
}

// 사용 예
takeHeapSnapshot('./heap-snapshot-before.heapsnapshot');

// ... 애플리케이션 실행 ...

takeHeapSnapshot('./heap-snapshot-after.heapsnapshot');

// Chrome DevTools에서 비교 분석 가능
```

### 4.3 실시간 메모리 추적

```javascript
class MemoryMonitor {
  constructor(thresholdMB = 500) {
    this.threshold = thresholdMB * 1024 * 1024;
    this.samples = [];
  }

  start(interval = 5000) {
    this.intervalId = setInterval(() => {
      const usage = process.memoryUsage();
      this.samples.push({
        timestamp: Date.now(),
        heapUsed: usage.heapUsed,
        rss: usage.rss
      });

      // 최근 100개만 유지
      if (this.samples.length > 100) {
        this.samples.shift();
      }

      // 임계값 체크
      if (usage.heapUsed > this.threshold) {
        console.warn('⚠️ Memory threshold exceeded!');
        this.analyze();
      }
    }, interval);
  }

  analyze() {
    const recent = this.samples.slice(-10);
    const avgGrowth = recent.reduce((acc, sample, i) => {
      if (i === 0) return 0;
      return acc + (sample.heapUsed - recent[i - 1].heapUsed);
    }, 0) / (recent.length - 1);

    console.log(`Average memory growth: ${Math.round(avgGrowth / 1024 / 1024)} MB/interval`);

    if (avgGrowth > 0) {
      console.warn('⚠️ Possible memory leak detected!');
    }
  }

  stop() {
    clearInterval(this.intervalId);
  }
}

// 사용 예
const monitor = new MemoryMonitor(500); // 500MB 임계값
monitor.start(5000); // 5초마다 체크
```

## 5. V8 플래그를 통한 메모리 최적화

### 5.1 힙 크기 조정

```bash
# 최대 Old Space 크기 설정 (기본값: ~1.4GB)
node --max-old-space-size=4096 app.js  # 4GB

# 최대 New Space 크기 설정
node --max-semi-space-size=16 app.js   # 16MB

# 메모리 사용량이 큰 애플리케이션
node --max-old-space-size=8192 app.js  # 8GB
```

### 5.2 GC 최적화 플래그

```bash
# GC 로그 활성화
node --trace-gc app.js

# 상세 GC 통계
node --trace-gc --trace-gc-verbose app.js

# GC 강제 실행 허용
node --expose-gc app.js

# Incremental marking 비활성화 (디버깅용)
node --noincremental-marking app.js
```

### 5.3 프로덕션 최적화

```javascript
// package.json scripts
{
  "scripts": {
    "start": "node app.js",
    "start:prod": "node --max-old-space-size=4096 --optimize-for-size app.js",
    "start:monitor": "node --trace-gc --trace-gc-verbose app.js"
  }
}
```

## 6. 메모리 효율적인 코딩 패턴

### 6.1 스트림 사용

```javascript
const fs = require('fs');

// ❌ 나쁜 예: 전체 파일을 메모리에 로드
async function processLargeFile() {
  const content = await fs.promises.readFile('large-file.txt');
  // 파일이 크면 메모리 부족 발생
}

// ✅ 좋은 예: 스트림으로 청크 단위 처리
function processLargeFileStream() {
  const readStream = fs.createReadStream('large-file.txt');

  readStream.on('data', (chunk) => {
    // 청크 단위로 처리
    processChunk(chunk);
  });

  readStream.on('end', () => {
    console.log('Processing complete');
  });
}
```

### 6.2 객체 풀링

```javascript
// 객체를 재사용하여 GC 압력 감소
class ObjectPool {
  constructor(factory, reset, size = 100) {
    this.factory = factory;
    this.reset = reset;
    this.pool = [];
    this.size = size;
  }

  acquire() {
    if (this.pool.length > 0) {
      return this.pool.pop();
    }
    return this.factory();
  }

  release(obj) {
    if (this.pool.length < this.size) {
      this.reset(obj);
      this.pool.push(obj);
    }
  }
}

// 사용 예
const bufferPool = new ObjectPool(
  () => Buffer.allocUnsafe(1024),  // factory
  (buf) => buf.fill(0),             // reset
  50                                 // pool size
);

function processData(data) {
  const buffer = bufferPool.acquire();
  // buffer 사용
  buffer.write(data);
  processBuffer(buffer);
  bufferPool.release(buffer);
}
```

### 6.3 WeakMap/WeakSet 활용

```javascript
// WeakMap: 키가 GC되면 자동으로 항목 제거
const cache = new WeakMap();

function cacheData(obj, data) {
  cache.set(obj, data);
  // obj가 더 이상 참조되지 않으면 cache 항목도 GC됨
}

// 실제 사용 예: DOM 노드 메타데이터
class ComponentManager {
  constructor() {
    this.metadata = new WeakMap();
  }

  setMetadata(element, data) {
    this.metadata.set(element, data);
  }

  getMetadata(element) {
    return this.metadata.get(element);
  }

  // element가 제거되면 metadata도 자동으로 GC됨
}
```

### 6.4 명시적 null 할당

```javascript
// ❌ 나쁜 예
function processHugeData() {
  const hugeArray = new Array(1000000).fill('data');
  doSomething(hugeArray);
  // hugeArray가 함수 끝까지 메모리 점유

  doOtherThings(); // 오래 걸리는 작업
}

// ✅ 좋은 예
function processHugeData() {
  let hugeArray = new Array(1000000).fill('data');
  doSomething(hugeArray);

  hugeArray = null; // 명시적으로 참조 해제

  doOtherThings(); // GC가 hugeArray를 회수할 수 있음
}
```

## 7. 실전 메모리 디버깅 워크플로우

### 7.1 메모리 누수 감지

```javascript
// 1. 메모리 증가 모니터링
const memwatch = require('@airbnb/node-memwatch');

memwatch.on('leak', (info) => {
  console.error('Memory leak detected:');
  console.error(info);
});

memwatch.on('stats', (stats) => {
  console.log('GC stats:', {
    gcType: stats.gc_type,
    beforeGC: `${Math.round(stats.before / 1024 / 1024)} MB`,
    afterGC: `${Math.round(stats.after / 1024 / 1024)} MB`,
    duration: `${stats.duration} ms`
  });
});

// 2. 힙 스냅샷 비교
const hd = new memwatch.HeapDiff();

// ... 의심되는 작업 실행 ...

const diff = hd.end();
console.log('Heap diff:', diff);
```

### 7.2 프로파일링 도구

```bash
# Chrome DevTools로 프로파일링
node --inspect app.js

# 그리고 chrome://inspect 에서 연결

# Clinic.js로 종합 분석
npm install -g clinic
clinic doctor -- node app.js
clinic bubbleprof -- node app.js
clinic flame -- node app.js
```

## 8. 체크리스트

### 개발 시 체크사항

- [ ] 전역 변수 최소화
- [ ] 이벤트 리스너 정리 (removeListener)
- [ ] 타이머 정리 (clearInterval, clearTimeout)
- [ ] 클로저에서 불필요한 참조 제거
- [ ] 대용량 데이터는 스트림 사용
- [ ] WeakMap/WeakSet 활용 고려
- [ ] 순환 참조 방지

### 프로덕션 배포 전 체크사항

- [ ] 메모리 프로파일링 실시
- [ ] 부하 테스트로 메모리 누수 확인
- [ ] 적절한 힙 크기 설정
- [ ] 메모리 모니터링 설정
- [ ] 알림 임계값 설정

## 9. 유용한 도구

- **Chrome DevTools**: 힙 스냅샷, 타임라인 프로파일링
- **Clinic.js**: 종합 성능 분석
- **node-memwatch**: 메모리 누수 감지
- **heapdump**: 프로그래밍 방식으로 힙 덤프
- **pprof**: 구글의 프로파일링 도구

## 참고 자료

- [V8 공식 문서](https://v8.dev/blog/trash-talk)
- [Node.js 메모리 관리 가이드](https://nodejs.org/en/docs/guides/simple-profiling/)
- [메모리 누수 디버깅](https://nodejs.org/en/docs/guides/diagnostics/memory/)
