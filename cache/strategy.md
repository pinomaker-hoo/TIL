# 캐싱 전략 (Caching Strategies)

> 캐시를 읽고 쓰는 다양한 전략을 상세히 정리한다. 각 전략의 동작 방식, 장단점, 적합한 사용 사례와 코드 예제를 다룬다.

<br />

## 목차

1. [Cache Aside (Lazy Loading)](#1-cache-aside-lazy-loading)
2. [Read Through](#2-read-through)
3. [Write Through](#3-write-through)
4. [Write Behind (Write Back)](#4-write-behind-write-back)
5. [Write Around](#5-write-around)
6. [Refresh Ahead](#6-refresh-ahead)
7. [Stale While Revalidate](#7-stale-while-revalidate)
8. [Two-Tier Caching (다계층 캐싱)](#8-two-tier-caching-다계층-캐싱)
9. [Request Coalescing (요청 병합)](#9-request-coalescing-요청-병합)
10. [전략 조합 가이드](#10-전략-조합-가이드)

<br />

---

## 1. Cache Aside (Lazy Loading)

가장 널리 사용되는 캐싱 전략이다. 애플리케이션이 캐시와 DB를 직접 관리한다.

### 동작 흐름

```
[읽기]
Client → App → Cache 조회
                 ├─ Hit → 데이터 반환
                 └─ Miss → DB 조회 → Cache 저장 → 데이터 반환

[쓰기]
Client → App → DB 업데이트 → Cache 삭제 (Invalidation)
```

### 코드 예제

```typescript
async function getUser(id: string): Promise<User> {
  // 1. 캐시 조회
  const cached = await redis.get(`user:${id}`);
  if (cached) return JSON.parse(cached);

  // 2. DB 조회
  const user = await db.user.findOne({ where: { id } });

  // 3. 캐시 저장
  await redis.set(`user:${id}`, JSON.stringify(user), 'EX', 3600);

  return user;
}

async function updateUser(id: string, data: UpdateUserDto): Promise<User> {
  const user = await db.user.save({ id, ...data });

  // 캐시 무효화
  await redis.del(`user:${id}`);

  return user;
}
```

### 장단점

| 장점 | 단점 |
| --- | --- |
| 실제 요청된 데이터만 캐싱 (메모리 효율적) | 최초 요청 시 항상 Cache Miss |
| 캐시 장애 시에도 DB에서 직접 조회 가능 | 캐시와 DB 간 데이터 불일치 가능 (TTL 내 변경) |
| 구현이 단순하고 직관적 | 쓰기 시 Cache Miss + DB 조회의 Latency 발생 |

### 적합한 경우

- 읽기가 쓰기보다 훨씬 많은 서비스 (읽기 중심 워크로드)
- 모든 데이터를 캐싱할 필요가 없는 경우
- 캐시 장애 시에도 서비스가 동작해야 하는 경우

<br />

## 2. Read Through

Cache Aside와 유사하지만 **캐시 계층**이 데이터 로딩의 책임을 가진다. 애플리케이션은 항상 캐시에만 요청하고, Cache Miss 시 캐시가 직접 DB에서 데이터를 가져온다.

### 동작 흐름

```
[읽기]
Client → App → Cache 조회
                 ├─ Hit → 데이터 반환
                 └─ Miss → Cache가 직접 DB 조회 → Cache에 저장 → 데이터 반환

                 (App은 Cache만 바라봄, DB 접근 코드 없음)
```

### Cache Aside와의 차이

| 항목 | Cache Aside | Read Through |
| --- | --- | --- |
| DB 조회 주체 | 애플리케이션 | 캐시 계층 |
| 애플리케이션 코드 | 캐시 + DB 로직 모두 작성 | 캐시 호출만 작성 |
| 캐시 라이브러리 | 단순 Key-Value 저장소 | Data Loader 기능 필요 |

### 코드 예제

```typescript
// Read Through를 지원하는 캐시 래퍼
class ReadThroughCache {
  constructor(
    private redis: Redis,
    private loader: Record<string, (key: string) => Promise<unknown>>,
  ) {}

  async get<T>(namespace: string, key: string, ttl: number): Promise<T> {
    const cacheKey = `${namespace}:${key}`;
    const cached = await this.redis.get(cacheKey);
    if (cached) return JSON.parse(cached);

    // 캐시가 직접 데이터 로딩
    const data = await this.loader[namespace](key);
    await this.redis.set(cacheKey, JSON.stringify(data), 'EX', ttl);
    return data as T;
  }
}

// 사용
const cache = new ReadThroughCache(redis, {
  user: (id) => db.user.findOne({ where: { id } }),
  product: (id) => db.product.findOne({ where: { id } }),
});

const user = await cache.get<User>('user', '123', 3600);
```

### 적합한 경우

- 동일한 캐싱 로직이 여러 곳에서 반복되는 경우
- 캐시 접근 로직을 표준화하고 싶은 경우

<br />

## 3. Write Through

데이터를 쓸 때 **캐시와 DB를 동기적으로 함께 업데이트**한다. 쓰기가 완료되려면 캐시와 DB 모두 성공해야 한다.

### 동작 흐름

```
[쓰기]
Client → App → Cache 저장 → DB 저장 → 완료 응답
                 (두 저장소 모두 동기적으로 업데이트)

[읽기]
Client → App → Cache 조회 → Hit → 데이터 반환
                 (Cache에 항상 최신 데이터가 있으므로 Hit 확률 높음)
```

### 코드 예제

```typescript
async function saveProduct(dto: CreateProductDto): Promise<Product> {
  // DB 저장
  const product = await db.product.save(dto);

  // 캐시에도 동기적으로 저장
  await redis.set(
    `product:${product.id}`,
    JSON.stringify(product),
    'EX',
    3600,
  );

  return product;
}
```

### 장단점

| 장점 | 단점 |
| --- | --- |
| 캐시와 DB의 데이터 일관성 보장 | 쓰기 Latency 증가 (캐시 + DB 모두 기다림) |
| 읽기 시 항상 Cache Hit 가능 | 사용되지 않는 데이터도 캐싱 (메모리 낭비) |
| 데이터 손실 위험 없음 | 쓰기가 많으면 캐시 부하 증가 |

### 적합한 경우

- 데이터 일관성이 매우 중요한 서비스 (금융, 결제)
- 쓰기 후 즉시 읽기가 빈번한 경우
- 쓰기 빈도가 높지 않은 경우

<br />

## 4. Write Behind (Write Back)

데이터를 **캐시에만 먼저 쓰고**, 일정 시간 후 또는 일정 개수가 쌓이면 **비동기적으로 DB에 반영**한다.

### 동작 흐름

```
[쓰기]
Client → App → Cache 저장 → 즉시 완료 응답
                   │
                   └─ (비동기) 일정 주기/조건 → DB에 배치 저장

[읽기]
Client → App → Cache 조회 → Hit → 데이터 반환
```

### 코드 예제

```typescript
class WriteBehindCache {
  private writeQueue: Map<string, unknown> = new Map();
  private flushInterval: NodeJS.Timeout;

  constructor(private redis: Redis, private db: DataSource) {
    // 5초마다 DB에 배치 저장
    this.flushInterval = setInterval(() => this.flush(), 5000);
  }

  async set(key: string, data: unknown): Promise<void> {
    // 캐시에 즉시 저장
    await this.redis.set(key, JSON.stringify(data), 'EX', 3600);

    // 쓰기 큐에 추가
    this.writeQueue.set(key, data);
  }

  private async flush(): Promise<void> {
    if (this.writeQueue.size === 0) return;

    const entries = Array.from(this.writeQueue.entries());
    this.writeQueue.clear();

    // DB에 배치로 저장
    await Promise.all(
      entries.map(([key, data]) => this.persistToDB(key, data)),
    );
  }

  private async persistToDB(key: string, data: unknown): Promise<void> {
    // 키에서 엔티티 타입과 ID를 파싱하여 DB에 저장
    // 예: "product:123" → product 테이블, id=123
  }
}
```

### 장단점

| 장점 | 단점 |
| --- | --- |
| 쓰기 응답이 매우 빠름 | 캐시 장애 시 아직 DB에 반영되지 않은 데이터 손실 |
| DB 쓰기를 배치로 처리하여 부하 감소 | 구현 복잡도가 높음 |
| 빈번한 업데이트를 합쳐서 처리 가능 | DB와 캐시 간 일시적 불일치 발생 |

### 적합한 경우

- 쓰기가 매우 빈번한 서비스 (로그, 조회수, 좋아요)
- 약간의 데이터 손실이 허용되는 경우
- DB 부하를 최소화해야 하는 경우

<br />

## 5. Write Around

데이터를 **DB에만 직접 쓰고 캐시는 건드리지 않는** 전략이다. 캐시는 읽기 시에만 적재된다 (Cache Aside의 읽기 패턴과 결합).

### 동작 흐름

```
[쓰기]
Client → App → DB 저장 (캐시에는 쓰지 않음)

[읽기]
Client → App → Cache 조회
                 ├─ Hit → 데이터 반환
                 └─ Miss → DB 조회 → Cache 저장 → 데이터 반환
```

### 코드 예제

```typescript
// 쓰기: DB에만 저장
async function createLog(dto: CreateLogDto): Promise<Log> {
  return await db.log.save(dto);
  // 캐시에는 저장하지 않음
}

// 읽기: Cache Aside 패턴
async function getLog(id: string): Promise<Log> {
  const cached = await redis.get(`log:${id}`);
  if (cached) return JSON.parse(cached);

  const log = await db.log.findOne({ where: { id } });
  await redis.set(`log:${id}`, JSON.stringify(log), 'EX', 1800);
  return log;
}
```

### 장단점

| 장점 | 단점 |
| --- | --- |
| 쓰기 성능이 빠름 (캐시 저장 불필요) | 쓰기 직후 읽기 시 반드시 Cache Miss |
| 한 번만 쓰고 자주 읽지 않는 데이터에 효율적 | 쓰기 후 즉시 읽기가 필요하면 부적합 |
| 캐시 메모리를 불필요하게 사용하지 않음 | 캐시와 DB 간 불일치 가능 |

### 적합한 경우

- 쓰기 후 바로 읽히지 않는 데이터 (로그, 감사 기록)
- 한 번 쓰고 드물게 읽는 데이터
- 캐시 메모리를 절약해야 하는 경우

<br />

## 6. Refresh Ahead

캐시 만료 **전에** 백그라운드에서 미리 데이터를 갱신한다. TTL이 일정 비율 이하로 남으면 갱신을 트리거한다.

### 동작 흐름

```
TTL = 60초, Refresh Factor = 0.8 (80%)인 경우

0초 ─────── 48초 ──────── 60초
 │           │              │
 │ 정상 캐시  │ 갱신 트리거    │ 만료
 │  사용 구간 │ (백그라운드    │
 │           │  DB 재조회 +  │
 │           │  캐시 갱신)   │
```

### 코드 예제

```typescript
class RefreshAheadCache {
  private refreshing = new Set<string>();

  async get<T>(
    key: string,
    loader: () => Promise<T>,
    ttl: number,
    refreshFactor = 0.8,
  ): Promise<T | null> {
    const cached = await redis.get(key);
    if (!cached) {
      // Cache Miss: 일반 로딩
      const data = await loader();
      await redis.set(key, JSON.stringify(data), 'EX', ttl);
      return data;
    }

    // 남은 TTL 확인
    const remainingTTL = await redis.ttl(key);
    const refreshThreshold = ttl * (1 - refreshFactor);

    // TTL이 임계값 이하면 백그라운드 갱신
    if (remainingTTL <= refreshThreshold && !this.refreshing.has(key)) {
      this.refreshing.add(key);
      loader()
        .then((data) => redis.set(key, JSON.stringify(data), 'EX', ttl))
        .finally(() => this.refreshing.delete(key));
    }

    return JSON.parse(cached);
  }
}
```

### 장단점

| 장점 | 단점 |
| --- | --- |
| Cache Miss가 거의 발생하지 않음 | 예측이 빗나가면 불필요한 DB 조회 |
| 사용자는 항상 빠른 응답을 받음 | 구현 복잡도가 높음 |
| 캐시 만료로 인한 Latency Spike 방지 | 접근 빈도가 낮은 데이터도 갱신될 수 있음 |

### 적합한 경우

- 높은 트래픽에서 Cache Miss Latency를 허용할 수 없는 경우
- 데이터 갱신 비용이 크지 않은 경우
- 인기 있는 핫 데이터의 캐시 만료를 방지하고 싶은 경우

<br />

## 7. Stale While Revalidate

만료된 캐시 데이터를 **즉시 반환하면서** 백그라운드에서 새 데이터로 갱신한다. HTTP의 `stale-while-revalidate` 헤더에서 유래한 개념이다.

### 동작 흐름

```
Client → App → Cache 조회
                 ├─ 유효 → 데이터 반환
                 ├─ 만료 (stale 허용 구간) → 오래된 데이터 즉시 반환
                 │                          + 백그라운드에서 DB 조회 → 캐시 갱신
                 └─ 완전 만료 (stale 초과) → DB 조회 → 캐시 저장 → 반환
```

### 코드 예제

```typescript
interface CacheEntry<T> {
  data: T;
  createdAt: number;
}

class StaleWhileRevalidateCache {
  private revalidating = new Set<string>();

  async get<T>(
    key: string,
    loader: () => Promise<T>,
    freshMs: number,  // 신선한 기간 (예: 60초)
    staleMs: number,  // stale 허용 기간 (예: 300초)
  ): Promise<T | null> {
    const raw = await redis.get(key);

    if (raw) {
      const entry: CacheEntry<T> = JSON.parse(raw);
      const age = Date.now() - entry.createdAt;

      if (age < freshMs) {
        // 신선한 데이터 → 바로 반환
        return entry.data;
      }

      if (age < freshMs + staleMs) {
        // Stale 데이터 → 반환 + 백그라운드 갱신
        if (!this.revalidating.has(key)) {
          this.revalidating.add(key);
          this.revalidate(key, loader, freshMs + staleMs)
            .finally(() => this.revalidating.delete(key));
        }
        return entry.data;
      }
    }

    // 캐시 없음 또는 완전 만료 → 동기적 로딩
    const data = await loader();
    const entry: CacheEntry<T> = { data, createdAt: Date.now() };
    await redis.set(key, JSON.stringify(entry), 'PX', freshMs + staleMs);
    return data;
  }

  private async revalidate<T>(
    key: string,
    loader: () => Promise<T>,
    totalMs: number,
  ): Promise<void> {
    const data = await loader();
    const entry: CacheEntry<T> = { data, createdAt: Date.now() };
    await redis.set(key, JSON.stringify(entry), 'PX', totalMs);
  }
}
```

### 적합한 경우

- 약간 오래된 데이터라도 빠른 응답이 중요한 서비스
- 프론트엔드 API 캐싱 (TanStack Query, SWR의 기본 전략)
- 사용자 경험을 우선하는 경우

<br />

## 8. Two-Tier Caching (다계층 캐싱)

**로컬 In-Memory 캐시(L1)**와 **분산 캐시(L2, Redis)**를 조합하여 사용하는 전략이다. L1에서 먼저 조회하고, Miss 시 L2를 조회한다.

### 동작 흐름

```
Client → App → L1 (In-Memory)
                  ├─ Hit → 데이터 반환 (네트워크 비용 0)
                  └─ Miss → L2 (Redis)
                              ├─ Hit → L1에 저장 → 데이터 반환
                              └─ Miss → DB 조회 → L2 저장 → L1 저장 → 반환
```

### 코드 예제

```typescript
class TwoTierCache {
  private l1 = new Map<string, { data: unknown; expiry: number }>();

  constructor(private redis: Redis) {}

  async get<T>(key: string, loader: () => Promise<T>, ttl: number): Promise<T> {
    // L1 조회
    const l1Entry = this.l1.get(key);
    if (l1Entry && Date.now() < l1Entry.expiry) {
      return l1Entry.data as T;
    }

    // L2 조회
    const l2Data = await this.redis.get(key);
    if (l2Data) {
      const parsed = JSON.parse(l2Data) as T;
      this.l1.set(key, { data: parsed, expiry: Date.now() + 10000 }); // L1 TTL: 10초
      return parsed;
    }

    // DB 조회
    const data = await loader();
    await this.redis.set(key, JSON.stringify(data), 'EX', ttl);
    this.l1.set(key, { data, expiry: Date.now() + 10000 });

    return data;
  }

  async invalidate(key: string): Promise<void> {
    this.l1.delete(key);
    await this.redis.del(key);
  }
}
```

### 장단점

| 장점 | 단점 |
| --- | --- |
| L1 Hit 시 네트워크 비용 0 (가장 빠름) | L1 캐시 간 데이터 불일치 (다중 인스턴스) |
| Redis 부하 감소 | 메모리를 이중으로 사용 |
| 핫 데이터에 대해 극도로 빠른 응답 | 무효화 복잡도 증가 |

### 적합한 경우

- 극도로 낮은 Latency가 필요한 서비스
- 읽기 빈도가 매우 높은 핫 데이터
- 다중 인스턴스에서 짧은 L1 TTL로 불일치를 허용할 수 있는 경우

<br />

## 9. Request Coalescing (요청 병합)

동일한 캐시 키에 대해 **동시에 여러 요청이 들어올 때 하나의 DB 조회만 실행**하고 나머지 요청은 그 결과를 공유하는 전략이다. Cache Stampede를 방지한다.

### 동작 흐름

```
요청 A ──┐
요청 B ──┼─→ 동일한 키? ─→ 하나만 DB 조회 ─→ 결과를 A, B, C 모두에게 반환
요청 C ──┘
```

### 코드 예제

```typescript
class CoalescingCache {
  private inFlight = new Map<string, Promise<unknown>>();

  async get<T>(key: string, loader: () => Promise<T>, ttl: number): Promise<T> {
    // 캐시 조회
    const cached = await redis.get(key);
    if (cached) return JSON.parse(cached);

    // 이미 같은 키의 요청이 진행 중이면 그 결과를 기다림
    if (this.inFlight.has(key)) {
      return this.inFlight.get(key) as Promise<T>;
    }

    // 새로운 DB 조회 시작
    const promise = loader().then(async (data) => {
      await redis.set(key, JSON.stringify(data), 'EX', ttl);
      this.inFlight.delete(key);
      return data;
    });

    this.inFlight.set(key, promise);
    return promise as Promise<T>;
  }
}
```

### 적합한 경우

- 캐시 만료 순간 동시 요청이 많은 경우 (Cache Stampede 방지)
- 인기 키에 대한 순간 트래픽이 높은 서비스

<br />

## 10. 전략 조합 가이드

실무에서는 단일 전략보다 여러 전략을 조합하여 사용하는 경우가 많다.

### 시나리오별 권장 조합

| 시나리오 | 읽기 전략 | 쓰기 전략 | 추가 전략 |
| --- | --- | --- | --- |
| 일반 CRUD API | Cache Aside | Write Around | — |
| 높은 읽기/낮은 쓰기 (카탈로그) | Read Through | Write Through | Refresh Ahead |
| 높은 쓰기 (로그, 조회수) | Cache Aside | Write Behind | Request Coalescing |
| 실시간 + 빠른 응답 | Two-Tier | Write Through | Stale While Revalidate |
| 마이크로서비스 간 공유 | Read Through | Write Through | Two-Tier |

### 의사결정 플로우

```
데이터 일관성이 중요한가?
  ├─ Yes → Write Through + Cache Aside
  └─ No
       │
       쓰기가 빈번한가?
         ├─ Yes → Write Behind + Cache Aside
         └─ No
              │
              응답 속도가 최우선인가?
                ├─ Yes → Two-Tier + Stale While Revalidate
                └─ No → Cache Aside + Write Around (가장 단순)
```
