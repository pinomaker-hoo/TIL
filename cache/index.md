# Cache (캐시)

## 개요

캐시(Cache)에 대해 학습한다. 캐시의 기본 개념부터 동작 원리, 전략, 무효화까지 정리하고, 백엔드와 프론트엔드에서의 캐시 활용법을 다룬다.

<br />

## 목차

- [캐싱 전략 - 읽기/쓰기 캐시 전략 상세 정리](./strategy.md)
- [백엔드 캐시 - API 서버에서의 캐시 활용법](./backend.md)
- [프론트엔드 캐시 - 브라우저 및 클라이언트 캐시 활용법](./frontend.md)

<br />

---

## 1. 캐시란 무엇인가?

캐시(Cache)는 자주 사용되는 데이터를 원본 저장소보다 빠르게 접근할 수 있는 임시 저장소에 보관하는 기술이다. 데이터 접근 속도를 높이고 원본 저장소(DB, API, 디스크 등)의 부하를 줄이는 것이 핵심 목적이다.

```
Client ──── 요청 ───→ Cache ──── Cache Hit ───→ 데이터 반환 (빠름)
                        │
                     Cache Miss
                        │
                        ▼
                   Origin (DB/API)
                        │
                   데이터 반환 + 캐시 저장
```

### 핵심 용어

- **Cache Hit**: 요청한 데이터가 캐시에 존재하여 바로 반환하는 경우
- **Cache Miss**: 요청한 데이터가 캐시에 없어 원본 저장소에서 조회해야 하는 경우

<br />

## 2. 캐시의 동작 원리

### (1) 기본 흐름

```
1. 클라이언트가 데이터를 요청한다.
2. 캐시에 해당 데이터가 있는지 확인한다.
   ├─ Cache Hit → 캐시에서 데이터를 바로 반환한다.
   └─ Cache Miss → 원본 저장소에서 데이터를 조회한다.
                   → 조회한 데이터를 캐시에 저장한다.
                   → 데이터를 반환한다.
```

### (2) Hit Ratio (캐시 적중률)

캐시의 효율을 측정하는 핵심 지표이다.

```
Hit Ratio = Cache Hit / (Cache Hit + Cache Miss)
```

- Hit Ratio가 높을수록 캐시가 효율적으로 동작하고 있다는 의미이다.
- 일반적으로 **80% 이상**의 Hit Ratio를 목표로 한다.

### (3) 캐시 모니터링 지표

캐시의 상태와 성능을 파악하기 위해 다음 지표들을 집계하여 모니터링한다.

| 지표 | 산출 방법 | 설명 |
| --- | --- | --- |
| Hit Ratio (적중률) | Hit / (Hit + Miss) | 캐시 효율의 핵심 지표. 80% 이상을 목표로 한다. |
| Miss Ratio (미스율) | Miss / (Hit + Miss) | 1 - Hit Ratio. 높을수록 캐시가 비효율적이다. |
| Hit Count | 누적 Hit 수 | 일정 시간 동안의 캐시 적중 횟수 |
| Miss Count | 누적 Miss 수 | 일정 시간 동안의 캐시 미스 횟수 |
| Eviction Count | 누적 제거 수 | 메모리 부족으로 캐시에서 강제 제거된 항목 수. 급증하면 메모리 부족 신호이다. |
| Latency (지연 시간) | 응답 시간 측정 | 캐시 Hit 시 응답 시간 vs Miss 시 응답 시간. 캐시 효과를 직접 측정한다. |
| Key Count | 현재 저장된 키 수 | 캐시에 저장된 항목의 총 개수. 메모리 사용량 예측에 활용한다. |
| Memory Usage | 캐시 메모리 사용량 | 전체 할당 메모리 대비 사용 비율. maxmemory에 근접하면 Eviction이 발생한다. |
| Expired Key Count | TTL 만료 삭제 수 | TTL에 의해 만료된 키의 수. TTL 설정이 적절한지 판단하는 기준이다. |
| Request Throughput | 초당 요청 수 (QPS) | 캐시에 들어오는 전체 요청 수. 부하 추이를 파악한다. |

### (4) Redis에서의 모니터링 확인

```bash
# Redis 서버 통계 확인
redis-cli INFO stats

# 주요 항목
keyspace_hits:12345        # 총 Cache Hit 수
keyspace_misses:678        # 총 Cache Miss 수
evicted_keys:0             # Eviction된 키 수
expired_keys:234           # TTL 만료된 키 수
total_commands_processed:50000  # 전체 처리 명령 수

# 메모리 확인
redis-cli INFO memory

used_memory_human:50.5M    # 현재 메모리 사용량
maxmemory_human:256M       # 최대 메모리 설정

# Hit Ratio 계산
# Hit Ratio = keyspace_hits / (keyspace_hits + keyspace_misses)
# 12345 / (12345 + 678) = 94.8%
```

### (5) Warm Cache vs Cold Cache

- **Cold Cache**: 캐시가 비어 있는 상태로, 모든 요청이 Cache Miss가 발생한다. 서버가 처음 시작되거나 캐시가 초기화된 직후의 상태이다.
- **Warm Cache**: 자주 사용되는 데이터가 이미 캐시에 적재된 상태로, 높은 Hit Ratio를 보인다.

<br />

## 3. 캐시의 종류

| 종류 | 위치 | 설명 | 예시 |
| --- | --- | --- | --- |
| CPU 캐시 | CPU | L1/L2/L3 하드웨어 레벨 캐시 | CPU 내장 |
| 메모리 캐시 | 애플리케이션 서버 | 프로세스 내부 메모리에 저장 | Node.js Map, node-cache |
| 분산 캐시 | 별도 서버 | 여러 서버에서 공유하는 외부 캐시 | Redis, Memcached |
| CDN 캐시 | 엣지 서버 | 사용자와 가까운 위치에서 정적 리소스 캐싱 | CloudFront, Cloudflare |
| 브라우저 캐시 | 클라이언트 | HTTP 응답을 브라우저에 저장 | Browser Cache |
| 디스크 캐시 | OS | 파일 시스템 레벨에서 자주 접근하는 데이터 캐싱 | OS Page Cache |

<br />

## 4. 캐시 전략

> 각 전략의 상세한 동작 방식, 코드 예제, 조합 가이드는 [캐싱 전략 문서](./strategy.md)를 참고한다. Redis에서의 캐시 전략은 [Redis 문서](../redis/redis.md)를 참고한다.

### (1) Cache Aside (Lazy Loading)

가장 일반적인 전략이다. 애플리케이션이 캐시를 직접 관리한다.

```
읽기: 캐시 조회 → Miss → DB 조회 → 캐시 저장 → 반환
쓰기: DB 업데이트 → 캐시 삭제 (또는 갱신)
```

- 장점: 실제 요청되는 데이터만 캐싱하여 메모리 효율적
- 단점: 최초 요청 시 항상 Cache Miss 발생

### (2) Read Through

Cache Aside와 유사하지만 캐시 계층 자체가 원본 저장소에서 데이터를 로딩하는 책임을 가진다. 애플리케이션은 항상 캐시에만 요청한다.

- 장점: 애플리케이션 코드가 단순해짐
- 단점: 캐시 라이브러리가 데이터 소스 접근 로직을 지원해야 함

### (3) Write Through

데이터를 쓸 때 캐시와 DB를 동시에 업데이트한다.

```
쓰기: 캐시 저장 → DB 저장 → 완료 응답
```

- 장점: 캐시와 DB의 데이터 일관성 보장
- 단점: 쓰기 지연 발생, 사용되지 않는 데이터도 캐싱될 수 있음

### (4) Write Behind (Write Back)

데이터를 캐시에만 먼저 쓰고 일정 시간 후 비동기적으로 DB에 반영한다.

- 장점: 쓰기 성능이 매우 빠름, DB 부하 감소
- 단점: 캐시 장애 시 데이터 손실 위험

### (5) Refresh Ahead

캐시 만료 전에 미리 데이터를 갱신하는 전략이다. 만료 시점에 가까운 데이터를 백그라운드에서 미리 조회하여 캐시를 갱신한다.

- 장점: Cache Miss 없이 항상 최신 데이터 제공
- 단점: 예측이 잘못되면 불필요한 리소스 소모

### 전략 비교

| 전략 | 읽기 성능 | 쓰기 성능 | 데이터 일관성 | 구현 복잡도 |
| --- | --- | --- | --- | --- |
| Cache Aside | 높음 (Hit 시) | 보통 | 낮음 | 낮음 |
| Read Through | 높음 (Hit 시) | 보통 | 낮음 | 보통 |
| Write Through | 높음 | 낮음 | 높음 | 보통 |
| Write Behind | 높음 | 매우 높음 | 낮음 | 높음 |
| Refresh Ahead | 매우 높음 | 보통 | 높음 | 높음 |

<br />

## 5. TTL (Time To Live)

TTL은 캐시 데이터의 유효 기간이다. 설정된 시간이 지나면 캐시 데이터가 자동으로 삭제(또는 무효화)된다.

### TTL 설정 기준

| 데이터 특성 | 권장 TTL | 예시 |
| --- | --- | --- |
| 거의 변하지 않는 데이터 | 24시간 이상 | 설정값, 코드 테이블 |
| 자주 변하지 않는 데이터 | 1~24시간 | 상품 목록, 카테고리 |
| 자주 변하는 데이터 | 1~5분 | 인기 순위, 검색 결과 |
| 실시간 데이터 | 캐시 사용 지양 | 재고 수량, 실시간 가격 |

### Jitter (지터)

대량의 캐시가 동시에 만료되면 원본 저장소에 갑작스러운 부하가 발생한다(Thundering Herd). 이를 방지하기 위해 TTL에 랜덤한 지터를 추가하여 만료 시점을 분산시킨다.

```
실제 TTL = 기본 TTL + Random(0, 기본 TTL * 0.1)
```

<br />

## 6. 캐시 무효화 (Cache Invalidation)

> "There are only two hard things in Computer Science: cache invalidation and naming things." — Phil Karlton

캐시 데이터가 원본 데이터와 일치하지 않을 때 캐시를 갱신하거나 삭제하는 과정이다.

### (1) TTL 기반 무효화

설정된 TTL이 만료되면 자연스럽게 캐시가 삭제된다. 가장 단순하지만 TTL 내에 데이터가 변경되면 오래된 데이터를 반환할 수 있다.

### (2) 이벤트 기반 무효화

데이터가 변경(생성/수정/삭제)될 때 즉시 관련 캐시를 삭제한다. 데이터 일관성이 중요할 때 사용한다.

```
데이터 업데이트 → 해당 캐시 키 삭제 → 다음 조회 시 새 데이터 캐싱
```

### (3) 버전 기반 무효화

캐시 키에 버전 정보를 포함하여 데이터가 변경되면 새로운 버전의 키를 사용한다.

```
product:v1:123 → product:v2:123
```

### (4) 태그 기반 무효화

관련된 캐시 항목들을 태그로 그룹화하고, 특정 태그에 속한 모든 캐시를 한 번에 무효화한다.

```
태그 "products" → product:1, product:2, product-list 모두 삭제
```

<br />

## 7. 캐시 사용 시 주의사항

- **Cache Stampede (Thundering Herd)**: 인기 있는 캐시 키가 만료되는 순간 다수의 요청이 동시에 원본 저장소로 몰리는 현상이다. 분산 락(Distributed Lock) 또는 Jitter를 활용하여 방지한다.

- **Stale Data (데이터 불일치)**: 캐시 데이터가 원본과 다른 상태를 보이는 문제이다. 적절한 TTL과 무효화 전략을 조합하여 해결한다.

- **Cold Start (콜드 스타트)**: 서버 시작 직후 캐시가 비어 있어 모든 요청이 원본 저장소로 가는 문제이다. Cache Warming(사전 로딩)으로 완화할 수 있다.

- **Cache Penetration (캐시 관통)**: 존재하지 않는 데이터에 대한 반복 요청이 매번 원본 저장소까지 도달하는 문제이다. Null 값도 캐싱하거나 Bloom Filter를 사용하여 방지한다.

- **Cache Avalanche (캐시 눈사태)**: 대량의 캐시가 동시에 만료되어 원본 저장소에 과부하가 발생하는 현상이다. TTL에 Jitter를 추가하여 만료 시점을 분산시킨다.

- **메모리 관리**: 캐시는 한정된 메모리를 사용하므로 적절한 Eviction 정책(LRU, LFU 등)을 설정해야 한다. Redis의 Eviction 정책에 대한 상세 내용은 [Redis 문서](../redis/redis.md)를 참고한다.
