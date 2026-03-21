# Redis

## 1. Redis란?

Redis(Remote Dictionary Server)는 오픈 소스 기반의 인메모리 데이터 구조 저장소로, 데이터베이스, 캐시, 메시지 브로커, 스트리밍 엔진 등으로 사용된다. 모든 데이터를 메모리에 저장하기 때문에 디스크 기반 데이터베이스에 비해 매우 빠른 읽기/쓰기 성능을 제공한다.

Redis는 Key-Value 구조를 기반으로 하며, 단순한 문자열뿐만 아니라 다양한 데이터 구조를 지원한다.

<br />

## 2. Redis의 특징

- **인메모리(In-Memory)**: 모든 데이터를 RAM에 저장하여 매우 빠른 응답 속도(평균 1ms 이하)를 제공한다.

- **싱글 스레드(Single Thread)**: 명령어 처리를 단일 스레드로 수행하여 Race Condition이 발생하지 않고 원자적(Atomic) 연산을 보장한다.

- **영속성(Persistence)**: 인메모리 저장소이지만 RDB, AOF 방식을 통해 디스크에 데이터를 저장하여 서버 재시작 시에도 데이터를 복구할 수 있다.

- **다양한 데이터 구조 지원**: String, List, Set, Sorted Set, Hash, Stream, Bitmap, HyperLogLog 등 풍부한 자료구조를 제공한다.

- **Pub/Sub**: 발행/구독 메시징 패턴을 기본으로 지원한다.

- **복제(Replication)**: Master-Replica 구조를 통해 데이터 복제 및 고가용성을 확보할 수 있다.

- **클러스터(Cluster)**: 여러 노드에 데이터를 분산 저장하여 수평 확장이 가능하다.

<br />

## 3. Redis 데이터 타입

### (1) String

가장 기본적인 데이터 타입으로 문자열, 숫자, 직렬화된 객체 등을 저장할 수 있다. 최대 512MB까지 저장 가능하다.

```bash
SET user:name "pinomaker"
GET user:name           # "pinomaker"

SET counter 100
INCR counter            # 101
DECRBY counter 10       # 91
```

### (2) List

문자열의 연결 리스트(Linked List)로 삽입 순서가 유지된다. 양쪽 끝에서 O(1)으로 요소를 추가/제거할 수 있어 큐(Queue)나 스택(Stack)으로 활용할 수 있다.

```bash
LPUSH queue "task1"
LPUSH queue "task2"
RPOP queue              # "task1"
LRANGE queue 0 -1       # ["task2"]
```

### (3) Set

순서가 없는 고유한 문자열의 집합이다. 중복을 허용하지 않으며 교집합, 합집합, 차집합 등의 집합 연산을 지원한다.

```bash
SADD tags "redis" "database" "cache"
SMEMBERS tags           # ["redis", "database", "cache"]
SISMEMBER tags "redis"  # 1 (true)

SADD tags2 "redis" "nosql"
SINTER tags tags2       # ["redis"]
```

### (4) Sorted Set (ZSet)

Set과 유사하지만 각 요소에 Score(점수)가 부여되어 Score 기준으로 정렬된다. 리더보드, 우선순위 큐 등에 활용된다.

```bash
ZADD leaderboard 100 "player1"
ZADD leaderboard 200 "player2"
ZADD leaderboard 150 "player3"

ZRANGE leaderboard 0 -1 WITHSCORES
# player1 100, player3 150, player2 200

ZREVRANGE leaderboard 0 0
# player2 (1등)
```

### (5) Hash

필드-값 쌍의 컬렉션으로 객체(Object)를 표현하기에 적합하다. 하나의 Key 아래에 여러 필드를 저장할 수 있다.

```bash
HSET user:1 name "pinomaker" age 25 role "developer"
HGET user:1 name        # "pinomaker"
HGETALL user:1          # name "pinomaker" age 25 role "developer"
HINCRBY user:1 age 1    # 26
```

### (6) Stream

이벤트 소싱, 메시지 큐 등에 사용되는 로그형 데이터 구조이다. Kafka와 유사한 소비자 그룹(Consumer Group)을 지원하여 안정적인 메시지 처리가 가능하다.

```bash
XADD mystream * action "login" user "pinomaker"
XADD mystream * action "purchase" item "book"

XRANGE mystream - +     # 모든 메시지 조회
XLEN mystream           # 메시지 수
```

<br />

## 4. 영속성(Persistence)

Redis는 인메모리 저장소이지만 데이터를 디스크에 저장하여 영속성을 보장하는 두 가지 방법을 제공한다.

### (1) RDB (Redis Database Snapshot)

특정 시점의 메모리 데이터를 스냅샷으로 저장하는 방식이다. 설정한 간격마다 자동으로 또는 수동으로 스냅샷을 생성한다.

| 장점 | 단점 |
| --- | --- |
| 압축된 바이너리 파일로 백업/복원이 빠름 | 스냅샷 사이의 데이터 손실 가능성 |
| 파일 크기가 작음 | fork 시 메모리 사용량 증가 |
| 재시작 시 로딩 속도가 빠름 | 대규모 데이터셋에서 fork 비용이 큼 |

```
# redis.conf
save 900 1      # 900초(15분) 동안 1번 이상 변경 시 스냅샷
save 300 10     # 300초(5분) 동안 10번 이상 변경 시 스냅샷
save 60 10000   # 60초(1분) 동안 10000번 이상 변경 시 스냅샷
```

### (2) AOF (Append Only File)

모든 쓰기 명령을 로그 파일에 순차적으로 기록하는 방식이다. 서버 재시작 시 로그를 재실행하여 데이터를 복구한다.

| 장점 | 단점 |
| --- | --- |
| 데이터 손실이 최소화됨 | 파일 크기가 RDB보다 큼 |
| 사람이 읽을 수 있는 형식 | 복구 속도가 RDB보다 느림 |
| fsync 정책 설정 가능 | 디스크 I/O 부하 |

```
# redis.conf
appendonly yes
appendfsync everysec    # 1초마다 fsync (권장)
# appendfsync always    # 매 명령마다 fsync (안전하지만 느림)
# appendfsync no        # OS에 위임 (빠르지만 위험)
```

### (3) RDB + AOF 혼합 방식

Redis 4.0부터 RDB와 AOF를 혼합하여 사용할 수 있다. AOF 재작성(rewrite) 시 RDB 형식으로 스냅샷을 생성하고 그 이후의 변경 사항만 AOF로 기록하여 빠른 복구와 데이터 안정성을 동시에 제공한다.

<br />

## 5. 캐시 전략

Redis를 캐시로 사용할 때 주로 사용하는 전략들이 있다.

### (1) Cache Aside (Lazy Loading)

가장 일반적인 캐시 전략으로, 애플리케이션이 먼저 캐시를 조회하고 캐시에 데이터가 없으면(Cache Miss) DB에서 조회한 후 캐시에 저장한다.

```
1. 캐시 조회 → Cache Hit → 캐시 데이터 반환
2. 캐시 조회 → Cache Miss → DB 조회 → 캐시에 저장 → 데이터 반환
```

- 장점: 실제로 요청된 데이터만 캐싱되어 메모리 효율적
- 단점: 최초 요청 시 항상 Cache Miss 발생, 캐시와 DB 간 데이터 불일치 가능

### (2) Write Through

데이터를 쓸 때 캐시와 DB를 동시에 업데이트하는 전략이다.

```
1. 데이터 쓰기 요청
2. 캐시에 저장
3. DB에 저장
4. 완료 응답
```

- 장점: 캐시와 DB의 데이터 일관성 보장
- 단점: 쓰기 지연 발생, 사용되지 않는 데이터도 캐싱될 수 있음

### (3) Write Behind (Write Back)

데이터를 캐시에만 먼저 쓰고 일정 시간 후 비동기적으로 DB에 반영하는 전략이다.

- 장점: 쓰기 성능이 매우 빠름, DB 부하 감소
- 단점: 캐시 장애 시 데이터 손실 위험, 구현 복잡도 높음

<br />

## 6. TTL (Time To Live)

Redis에서는 Key에 만료 시간을 설정하여 자동으로 삭제되게 할 수 있다. 캐시 데이터의 생명주기를 관리하는 핵심 기능이다.

```bash
SET session:abc123 "user_data"
EXPIRE session:abc123 3600      # 3600초(1시간) 후 만료

SETEX token:xyz 300 "value"     # 설정과 동시에 300초 TTL 지정

TTL session:abc123              # 남은 TTL 확인 (초 단위)
PERSIST session:abc123          # TTL 제거 (영구 저장)
```

### 만료 정책

Redis는 두 가지 방식을 조합하여 만료된 Key를 삭제한다.

- **Lazy Expiration**: Key에 접근할 때 만료 여부를 확인하고 삭제한다.
- **Active Expiration**: 주기적으로 만료된 Key를 샘플링하여 삭제한다. 매 100ms마다 만료된 Key 중 일부를 무작위로 선택하여 삭제한다.

<br />

## 7. Eviction 정책

Redis 메모리가 가득 찼을 때 어떤 Key를 제거할지 결정하는 정책이다. `maxmemory-policy` 설정으로 지정한다.

| 정책 | 설명 |
| --- | --- |
| noeviction | 메모리 초과 시 쓰기 명령에 에러 반환 (기본값) |
| allkeys-lru | 모든 Key 중 가장 오래 사용되지 않은 Key 제거 |
| allkeys-lfu | 모든 Key 중 가장 적게 사용된 Key 제거 |
| allkeys-random | 모든 Key 중 무작위로 제거 |
| volatile-lru | TTL이 설정된 Key 중 가장 오래 사용되지 않은 Key 제거 |
| volatile-lfu | TTL이 설정된 Key 중 가장 적게 사용된 Key 제거 |
| volatile-random | TTL이 설정된 Key 중 무작위로 제거 |
| volatile-ttl | TTL이 가장 짧은 Key 우선 제거 |

```
# redis.conf
maxmemory 256mb
maxmemory-policy allkeys-lru
```

<br />

## 8. Pub/Sub

Redis의 발행/구독(Publish/Subscribe) 메시징 패턴으로, 발행자(Publisher)가 채널에 메시지를 발행하면 해당 채널을 구독하는 모든 구독자(Subscriber)에게 메시지가 전달된다.

```bash
# 구독자 (터미널 1)
SUBSCRIBE chat:room1

# 발행자 (터미널 2)
PUBLISH chat:room1 "Hello, Redis!"
```

- Pub/Sub 메시지는 영속성이 없어 구독자가 없으면 메시지가 소실된다.
- 안정적인 메시지 전달이 필요하면 Redis Stream을 사용하는 것이 권장된다.

<br />

## 9. Redis 아키텍처

### (1) Standalone

단일 Redis 인스턴스로 구성하는 가장 간단한 형태이다. 개발 환경이나 소규모 서비스에 적합하지만 장애 시 서비스 중단이 발생한다.

### (2) Master-Replica (Replication)

Master 노드의 데이터를 하나 이상의 Replica 노드에 복제하는 구조이다. 읽기 요청을 Replica로 분산하여 부하를 줄일 수 있으며, Master 장애 시 Replica를 수동으로 승격시킬 수 있다.

```
Master (Read/Write)
  ├── Replica 1 (Read Only)
  └── Replica 2 (Read Only)
```

### (3) Sentinel

Master-Replica 구조에 모니터링과 자동 장애 조치(Failover)를 추가한 구성이다. Sentinel 프로세스가 Master를 감시하고, 장애가 감지되면 자동으로 Replica를 새 Master로 승격시킨다.

```
Sentinel 1 ── Sentinel 2 ── Sentinel 3
    │              │              │
    └──────── Master ─────────────┘
               ├── Replica 1
               └── Replica 2
```

- Sentinel은 최소 3개 이상의 홀수 개를 권장한다 (과반수 투표를 위해).

### (4) Cluster

데이터를 여러 노드에 분산 저장(Sharding)하는 구조로, 16384개의 해시 슬롯을 노드들이 나누어 담당한다. 대규모 데이터와 높은 처리량이 필요한 서비스에 적합하다.

```
Node 1 (Slot 0-5460)      ── Replica 1-1
Node 2 (Slot 5461-10922)  ── Replica 2-1
Node 3 (Slot 10923-16383) ── Replica 3-1
```

- 자동 Failover를 지원한다.
- 멀티 Key 연산은 같은 슬롯에 있는 Key에서만 가능하다 (Hash Tag 사용으로 해결 가능).

<br />

## 10. Redis 사용 시 주의사항

- **O(N) 명령 주의**: `KEYS *`, `FLUSHALL`, `SMEMBERS` (대규모 Set) 등 O(N) 명령은 싱글 스레드인 Redis를 블로킹하여 전체 서비스에 영향을 줄 수 있다. 대신 `SCAN` 명령을 사용하는 것이 권장된다.

- **메모리 관리**: 인메모리 저장소이므로 메모리 사용량을 모니터링하고 적절한 `maxmemory`와 Eviction 정책을 설정해야 한다.

- **Key 네이밍 규칙**: `서비스:엔티티:ID:필드`와 같은 계층적 네이밍 컨벤션을 사용하는 것이 관리에 용이하다 (예: `user:1:profile`, `session:abc123`).

- **Big Key 방지**: 하나의 Key에 너무 큰 데이터를 저장하면 네트워크 지연, 메모리 단편화, 삭제 시 블로킹 등의 문제가 발생할 수 있다.

- **Thundering Herd 문제**: 대량의 캐시가 동시에 만료되면 DB에 갑작스러운 부하가 발생할 수 있다. TTL에 랜덤한 지터(Jitter)를 추가하여 만료 시점을 분산시키는 것이 좋다.
