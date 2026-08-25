# 기술 면접 - DB

> 백엔드 면접에서 가장 비중이 큰 영역이다. 기준은 MySQL(InnoDB)이며, 필요한 곳에서 PostgreSQL과의 차이를 함께 정리한다.

<br />

## 목차

1. [출제 빈도 지도](#0-출제-빈도-지도)
2. [인덱스](#1-인덱스)
3. [트랜잭션과 격리 수준](#2-트랜잭션과-격리-수준)
4. [락과 데드락](#3-락과-데드락)
5. [InnoDB 내부 구조](#4-innodb-내부-구조)
6. [쿼리 최적화와 실행 계획](#5-쿼리-최적화와-실행-계획)
7. [정규화와 반정규화](#6-정규화와-반정규화)
8. [페이징](#7-페이징)
9. [커넥션 풀](#8-커넥션-풀)
10. [복제 · 파티셔닝 · 샤딩](#9-복제--파티셔닝--샤딩)
11. [RDB vs NoSQL](#10-rdb-vs-nosql)
12. [캐시와 DB 일관성](#11-캐시와-db-일관성)
13. [실무 경험 질문](#12-실무-경험-질문)
14. [학습 체크리스트](#13-학습-체크리스트)

<br />

---

## 0. 출제 빈도 지도

| 주제 | 빈도 | 깊이 요구 |
| --- | --- | --- |
| 인덱스 (B+Tree, 복합 인덱스, 커버링) | ★★★★★ | 자료구조 수준까지 |
| 트랜잭션 / 격리 수준 / MVCC | ★★★★★ | 이상 현상 재현 가능 수준 |
| 락 / 데드락 | ★★★★☆ | 실무 사례 필요 |
| 실행 계획 해석 | ★★★★☆ | EXPLAIN 컬럼 설명 |
| N+1, 쿼리 최적화 | ★★★★☆ | ORM 사용 경험 연계 |
| 정규화 / 반정규화 | ★★★☆☆ | 판단 기준 |
| 복제 / 샤딩 | ★★★☆☆ | 개념 + 트레이드오프 |
| RDB vs NoSQL | ★★★☆☆ | 선택 근거 |
| 커넥션 풀 | ★★★☆☆ | 장애 경험 연계 |

<br />

---

## 1. 인덱스

### Q1. 인덱스란 무엇이고 왜 빨라지는가?

**핵심 답변**

인덱스는 컬럼 값을 정렬된 자료구조로 별도 저장해 조회 속도를 높이는 객체다. InnoDB는 **B+Tree**를 사용한다.

- 풀 테이블 스캔은 O(N), B+Tree 탐색은 **O(log N)**이다.
- B+Tree는 **리프 노드에만 실제 데이터(또는 PK)가 있고, 리프끼리 연결 리스트로 이어져 있다.** 그래서 범위 검색(`BETWEEN`, `>`, `<`)과 정렬(`ORDER BY`)에 강하다.
- 대신 쓰기 시 인덱스도 함께 갱신해야 하므로 INSERT/UPDATE/DELETE가 느려지고 저장 공간을 더 쓴다.

```
[B+Tree 구조]

              ┌───── 30 | 60 ─────┐          ← Root
         ┌────┘        │           └────┐
    10 | 20         40 | 50         70 | 80   ← Branch
      │                │                │
 [1..29] ←→ [30..59] ←→ [60..89] ←→ ...       ← Leaf (연결 리스트)
   실제 데이터(클러스터드) 또는 PK(세컨더리)
```

<br />

### Q2. 왜 B-Tree(B+Tree)를 쓰는가? 해시 인덱스는 안 되는가?

- **해시 인덱스**는 `=` 조회는 O(1)로 가장 빠르지만, **범위 검색과 정렬이 불가능**하고 부분 일치(`LIKE 'abc%'`)도 안 된다.
- DB 조회는 범위·정렬 요구가 많으므로 B+Tree가 범용적이다.
- 또한 **디스크 I/O 최적화** 때문이다. B+Tree는 노드 하나가 디스크 페이지(InnoDB는 16KB) 크기에 맞춰 **한 번의 I/O로 많은 키를 읽는다**. 이진 트리는 높이가 커서 I/O 횟수가 폭증한다.

> 꼬리 질문: "그럼 Redis는 왜 해시를 쓰나요?" → 메모리 기반이고 키-값 단건 조회가 지배적이라 범위 탐색 요구가 적기 때문이다.

<br />

### Q3. 클러스터드 인덱스와 세컨더리 인덱스의 차이는?

| 구분 | 클러스터드 인덱스 | 세컨더리 인덱스 |
| --- | --- | --- |
| 개수 | 테이블당 1개 (보통 PK) | 여러 개 |
| 리프 노드 내용 | **실제 행 데이터 전체** | 인덱스 컬럼 + **PK 값** |
| 조회 방식 | 인덱스 탐색 = 데이터 도달 | 인덱스 탐색 → PK 획득 → 다시 클러스터드 탐색 (**북마크 룩업**) |
| 정렬 | 데이터가 PK 순으로 물리 정렬 | 인덱스 자체만 정렬 |

**중요 포인트**

- 세컨더리 인덱스는 리프에 PK를 담기 때문에 **PK가 크면 모든 세컨더리 인덱스가 같이 커진다.** → PK는 작고 단조 증가하는 값이 유리하다.
- **UUID를 PK로 쓰면 안 되는 이유**: 랜덤한 값이라 삽입 위치가 매번 달라져 **페이지 분할(page split)** 과 단편화가 심해지고, 16바이트라 세컨더리 인덱스도 커진다. 꼭 써야 하면 `UUIDv7`이나 `BINARY(16)` + 시간 정렬 가능한 형태를 쓴다.
- PostgreSQL은 클러스터드 인덱스 개념이 없고 힙(heap) + 인덱스가 ctid를 가리키는 구조라 이 차이가 자주 비교 질문으로 나온다.

<br />

### Q4. 복합 인덱스의 컬럼 순서는 어떻게 정하는가?

**핵심 답변: 왼쪽부터 순서대로 쓰여야 인덱스를 탄다 (Leftmost Prefix Rule).**

`INDEX (a, b, c)` 인 경우

| 조건 | 인덱스 사용 |
| --- | --- |
| `WHERE a = 1` | O |
| `WHERE a = 1 AND b = 2` | O |
| `WHERE a = 1 AND b = 2 AND c = 3` | O (전부 사용) |
| `WHERE b = 2` | X |
| `WHERE a = 1 AND c = 3` | a만 사용, c는 필터링 |
| `WHERE a > 1 AND b = 2` | **a까지만 범위 탐색**, b는 인덱스로 못 좁힘 |

**순서 결정 기준**

1. `=` 조건 컬럼을 앞에, **범위 조건(`>`, `<`, `BETWEEN`, `LIKE 'x%'`) 컬럼을 뒤에** 둔다. 범위 조건이 걸린 순간 그 뒤 컬럼은 인덱스로 범위를 좁히지 못한다.
2. 그다음 `ORDER BY` / `GROUP BY` 컬럼을 둔다. → 인덱스 정렬을 그대로 써서 `Using filesort`를 없앨 수 있다.
3. 같은 조건이면 **카디널리티(중복도가 낮은 = 값 종류가 많은)** 가 높은 컬럼을 앞에 둔다.

```sql
-- 나쁜 예: created_at이 범위라 status가 인덱스를 못 탄다
INDEX (created_at, status)
WHERE created_at >= '2026-01-01' AND status = 'PAID'

-- 좋은 예
INDEX (status, created_at)
WHERE status = 'PAID' AND created_at >= '2026-01-01'
```

<br />

### Q5. 커버링 인덱스란?

쿼리가 필요로 하는 **모든 컬럼이 인덱스 안에 다 들어 있어서, 실제 테이블(클러스터드 인덱스)에 접근하지 않고 인덱스만 읽고 끝나는 것**을 말한다. 실행 계획의 `Extra`에 `Using index`가 뜬다.

```sql
INDEX idx_user_status (user_id, status, amount)

-- 커버링 O : 세 컬럼이 모두 인덱스에 있음 → 북마크 룩업 없음
SELECT status, amount FROM orders WHERE user_id = 1;

-- 커버링 X : description은 인덱스에 없음 → 테이블 접근 발생
SELECT status, description FROM orders WHERE user_id = 1;
```

효과가 큰 이유는 **랜덤 I/O(북마크 룩업)를 없애기 때문**이다. 특히 페이징에서 위력이 크다.

<br />

### Q6. 인덱스를 타지 못하는 대표적인 경우는?

```sql
-- 1. 컬럼에 함수/연산 적용 (인덱스는 원본 값 기준으로 정렬되어 있음)
WHERE DATE(created_at) = '2026-08-25'      -- X
WHERE created_at >= '2026-08-25 00:00:00'  -- O
     AND created_at <  '2026-08-26 00:00:00'

-- 2. 앞에 와일드카드가 있는 LIKE
WHERE name LIKE '%kim'   -- X (풀스캔)
WHERE name LIKE 'kim%'   -- O

-- 3. 타입 불일치 → 암묵적 형변환
WHERE phone = 01012345678   -- phone이 VARCHAR면 형변환되어 인덱스 미사용
WHERE phone = '01012345678' -- O

-- 4. OR로 인덱스 없는 컬럼이 섞임
WHERE indexed_col = 1 OR non_indexed_col = 2   -- 풀스캔 (UNION으로 분리 가능)

-- 5. 부정 조건
WHERE status != 'DONE'   -- 대부분 풀스캔

-- 6. 카디널리티가 너무 낮음 (예: is_deleted 0/1)
-- 옵티마이저가 "어차피 절반 이상 읽을 거면 풀스캔이 낫다"고 판단 (보통 20~25% 이상)
```

> 6번이 핵심 포인트다. **인덱스가 있어도 옵티마이저가 안 쓸 수 있다.** "인덱스를 걸었는데 안 탄다"는 질문의 답은 대부분 카디널리티/통계 정보다.

<br />

### 공부할 것

- B+Tree vs B-Tree vs 해시 vs LSM Tree 차이
- 카디널리티, 선택도(selectivity)
- `SHOW INDEX FROM table` 의 `Cardinality` 읽는 법, `ANALYZE TABLE`로 통계 갱신
- 커버링 인덱스, 인덱스 스킵 스캔, 인덱스 머지
- 페이지 분할과 단편화, `OPTIMIZE TABLE`
- 참고: [MySQL 인덱스](../mysql/sql-index.md), [인덱스 2](../mysql/sql-index-2.md), [인덱스 최적화](../db/mysql/index-optimization.md)

<br />

---

## 2. 트랜잭션과 격리 수준

### Q1. ACID를 설명하라.

| 속성 | 의미 | 보장 수단 |
| --- | --- | --- |
| **A**tomicity (원자성) | 전부 성공하거나 전부 실패 | **Undo Log** (롤백용 이전 값 기록) |
| **C**onsistency (일관성) | 트랜잭션 전후로 무결성 제약이 유지됨 | 제약조건, 트리거, 애플리케이션 로직 |
| **I**solation (격리성) | 동시 실행 트랜잭션이 서로 간섭하지 않음 | **Lock + MVCC** |
| **D**urability (지속성) | 커밋된 데이터는 장애가 나도 보존 | **Redo Log + WAL(Write-Ahead Logging)** |

> 각 속성을 **"무엇으로 구현하는가"** 까지 말하면 확실히 차이가 난다.

<br />

### Q2. 격리 수준 4단계와 각 단계에서 생기는 이상 현상은?

| 격리 수준 | Dirty Read | Non-Repeatable Read | Phantom Read |
| --- | --- | --- | --- |
| READ UNCOMMITTED | 발생 | 발생 | 발생 |
| READ COMMITTED (PostgreSQL/Oracle 기본) | X | 발생 | 발생 |
| REPEATABLE READ (**MySQL 기본**) | X | X | 발생(이론) / **InnoDB는 대부분 방지** |
| SERIALIZABLE | X | X | X |

**이상 현상 정의**

- **Dirty Read**: 커밋되지 않은 다른 트랜잭션의 변경을 읽음.
- **Non-Repeatable Read**: 같은 행을 두 번 읽었는데 값이 달라짐 (다른 트랜잭션의 UPDATE 커밋 때문).
- **Phantom Read**: 같은 조건으로 두 번 조회했는데 **없던 행이 생기거나 사라짐** (다른 트랜잭션의 INSERT/DELETE 때문).

**MySQL InnoDB의 특이점 (자주 나오는 꼬리 질문)**

- InnoDB의 REPEATABLE READ에서는 **일반 SELECT(Consistent Read)는 MVCC 스냅샷을 읽으므로 팬텀 리드가 발생하지 않는다.**
- 단, `SELECT ... FOR UPDATE` / `FOR SHARE` 같은 **잠금 읽기(Locking Read)** 는 최신 데이터를 읽으므로 팬텀이 발생할 수 있고, 이를 **Gap Lock / Next-Key Lock**으로 막는다.

<br />

### Q3. MVCC란 무엇인가?

**Multi-Version Concurrency Control** — 하나의 데이터에 대해 여러 버전을 유지해서, **읽기가 쓰기를 막지 않고 쓰기가 읽기를 막지 않게** 하는 기법이다.

동작 방식 (InnoDB 기준)

1. 각 행에는 숨은 컬럼 `DB_TRX_ID`(마지막 변경 트랜잭션 ID), `DB_ROLL_PTR`(Undo 로그 포인터)가 있다.
2. UPDATE가 일어나면 **이전 버전은 Undo Log에 남고**, 행은 새 값으로 갱신된다.
3. 다른 트랜잭션이 읽을 때 자신의 **Read View**와 `DB_TRX_ID`를 비교해서, 자기가 볼 수 있는 버전이 아니면 **Undo Log를 따라가 과거 버전을 읽는다.**

```
Row(id=1) : name = "B"   TRX_ID = 20  ──ROLL_PTR──→ Undo: name="A" (TRX_ID=10)

TRX 15 (Read View 생성 시점: 15) 가 읽으면
  → 현재 버전 TRX_ID 20 은 내 뒤에 시작 → 못 봄
  → Undo 따라가서 name = "A" 를 읽음
```

- READ COMMITTED: **쿼리마다** Read View를 새로 만든다 → Non-Repeatable Read 발생.
- REPEATABLE READ: **트랜잭션 시작 시 한 번** Read View를 만든다 → 계속 같은 스냅샷.

**주의점**: 트랜잭션을 길게 열어두면 Undo 로그가 정리(purge)되지 못해 **언두 테이블스페이스가 계속 커지고 조회가 느려진다.** (긴 트랜잭션이 위험한 이유)

<br />

### Q4. 트랜잭션은 어디까지 묶어야 하나?

**핵심 답변: 짧게, DB 작업만.**

```typescript
// 나쁜 예 — 외부 API 호출이 트랜잭션 안에 있다
@Transactional()
async createOrder(dto) {
  const order = await this.orderRepo.save(dto);
  await this.pgClient.pay(order);      // 3초 걸리면 그동안 락을 잡고 있음
  await this.mailer.send(order);       // 실패하면 결제는 됐는데 롤백됨
}

// 좋은 예 — 트랜잭션은 DB만, 외부 연동은 커밋 이후 이벤트로
async createOrder(dto) {
  const order = await this.dataSource.transaction(async (m) => {
    const saved = await m.save(Order, dto);
    await m.save(OutboxEvent, { type: 'ORDER_CREATED', payload: saved });  // 아웃박스
    return saved;
  });
  // 커밋 후 별도 워커가 아웃박스를 읽어 결제/메일 처리
}
```

- 트랜잭션이 길수록 락 보유 시간이 길어져 **경합 → 대기 → 커넥션 고갈 → 서비스 전체 장애**로 번진다.
- 외부 API, 파일 I/O, 무거운 연산은 트랜잭션 밖으로 뺀다.
- 관련: [MSA - Outbox 패턴](./msa.md#q3-outbox-패턴이란)

<br />

### 공부할 것

- ACID와 각각의 구현 수단 (Undo/Redo/WAL)
- 4가지 격리 수준과 이상 현상, MySQL vs PostgreSQL 기본값 차이
- MVCC, Read View, Undo Log, purge
- 격리 수준별 동작 **직접 재현**해보기 (터미널 두 개로 `SET SESSION TRANSACTION ISOLATION LEVEL ...`)
- 스프링 `@Transactional` 전파 속성 / TypeORM `QueryRunner`, `transaction()`
- 참고: [MySQL 트랜잭션](../mysql/transaction.md)

<br />

---

## 3. 락과 데드락

### Q1. 공유 락과 배타 락의 차이는?

| 락 | 표기 | 획득 방법 | 호환성 |
| --- | --- | --- | --- |
| 공유 락 (Shared) | S | `SELECT ... FOR SHARE` | S끼리는 동시 가능, X와는 불가 |
| 배타 락 (Exclusive) | X | `SELECT ... FOR UPDATE`, `UPDATE`, `DELETE` | 아무와도 동시 불가 |

<br />

### Q2. 레코드 락, 갭 락, 넥스트 키 락의 차이는?

```
인덱스 값:     10        20        30
갭:        (-∞,10)  (10,20)  (20,30)  (30,+∞)

레코드 락   : 20 이라는 "행"만 잠금
갭 락       : (10,20) 처럼 값 사이의 "빈 구간"을 잠금 → 그 사이 INSERT 차단
넥스트 키 락 : 레코드 락 + 그 앞의 갭 락 = (10, 20] → InnoDB REPEATABLE READ의 기본
```

- **갭 락의 목적은 팬텀 리드 방지**다. 값이 없어도 그 구간에 INSERT를 못 하게 막는다.
- 그래서 InnoDB에서는 **존재하지 않는 행에 `FOR UPDATE`를 걸어도 락이 잡히고**, 이게 데드락의 흔한 원인이 된다.
- READ COMMITTED로 낮추면 갭 락이 거의 사라져 동시성은 올라가지만 팬텀이 생긴다.

<br />

### Q3. 데드락은 왜 생기고 어떻게 해결하는가?

**원인**: 두 트랜잭션이 **서로 다른 순서로** 같은 자원에 락을 요청할 때.

```
TRX A : UPDATE user WHERE id=1  →  UPDATE user WHERE id=2  (2를 기다림)
TRX B : UPDATE user WHERE id=2  →  UPDATE user WHERE id=1  (1을 기다림)
                                    → 순환 대기 = 데드락
```

**해결/예방**

1. **락 획득 순서를 통일한다.** (가장 근본적 — 항상 PK 오름차순으로 접근, `IN (...)` 절 정렬)
2. 트랜잭션을 짧게 유지한다.
3. 격리 수준을 READ COMMITTED로 낮춰 갭 락을 줄인다.
4. 인덱스를 제대로 걸어 **락 범위를 좁힌다.** (인덱스가 없으면 풀스캔하며 모든 행에 락을 걸어 데드락 확률이 급증한다 — 자주 나오는 포인트)
5. InnoDB는 데드락을 감지하면 **비용이 적은 쪽을 자동 롤백**하므로, 애플리케이션에서 **재시도 로직**을 둔다.

**진단**: `SHOW ENGINE INNODB STATUS` 의 `LATEST DETECTED DEADLOCK` 섹션, `information_schema.INNODB_TRX`, `performance_schema.data_locks`.

<br />

### Q4. 비관적 락 vs 낙관적 락

| 구분 | 비관적 락 (Pessimistic) | 낙관적 락 (Optimistic) |
| --- | --- | --- |
| 전제 | 충돌이 자주 난다 | 충돌이 드물다 |
| 방법 | `SELECT ... FOR UPDATE`로 미리 잠금 | `version` 컬럼 비교 후 UPDATE, 실패 시 재시도 |
| 장점 | 확실한 정합성 | 락 대기 없음, 처리량 높음 |
| 단점 | 대기/데드락, 처리량 저하 | 충돌 시 재시도 비용, 롤백 처리 필요 |
| 예시 | 재고 차감, 좌석 예약, 포인트 차감 | 게시글 수정, 프로필 변경 |

```sql
-- 낙관적 락
UPDATE product SET stock = stock - 1, version = version + 1
WHERE id = 1 AND version = 5;
-- affectedRows = 0 이면 다른 트랜잭션이 먼저 바꾼 것 → 재시도
```

> **선착순 쿠폰/재고 차감 문제**는 단골 질문이다. 답변 흐름:
> 1) `stock = stock - 1` 같은 **원자적 UPDATE** + `WHERE stock > 0` 조건으로 애플리케이션 read-modify-write를 제거한다.
> 2) 트래픽이 더 크면 DB 락으로는 감당이 안 되므로 **Redis 원자 연산(`DECR`, Lua 스크립트)** 으로 선착순을 판정하고 DB는 비동기로 반영한다.
> 3) 분산 환경 상호배제가 필요하면 **Redis 분산 락(Redlock, Redisson)** 을 쓰되 TTL과 락 소유권 검증을 반드시 다룬다.

<br />

### 공부할 것

- S/X 락, 인텐션 락, 레코드/갭/넥스트키 락
- 데드락 감지 원리, `innodb_lock_wait_timeout`, `innodb_deadlock_detect`
- 비관적/낙관적 락, TypeORM `pessimistic_write` / `@VersionColumn`
- 분산 락 (Redis SETNX + TTL, Redlock 논쟁) — [Redis](../redis/redis.md)
- 선착순 처리 아키텍처 (DB 락 → Redis → 큐)

<br />

---

## 4. InnoDB 내부 구조

### Q1. 버퍼 풀(Buffer Pool)이란?

디스크의 데이터/인덱스 페이지를 메모리에 캐싱하는 InnoDB의 핵심 영역이다.

- 조회 시 버퍼 풀에 있으면 디스크 I/O 없이 응답한다 → **Buffer Pool Hit Ratio가 99% 이상이 목표.**
- 변경도 우선 버퍼 풀의 **더티 페이지(Dirty Page)** 로 만들고, 나중에 디스크에 flush 한다.
- 일반적으로 물리 메모리의 **50~70%** 를 `innodb_buffer_pool_size`로 할당한다.
- 교체 정책은 **개선된 LRU(Young/Old 서브리스트)** 를 쓴다. 풀스캔 한 번으로 캐시가 전부 밀려나가는 것을 막기 위해, 새로 읽은 페이지를 old 영역에 넣고 일정 시간 뒤 다시 접근돼야 young으로 승격시킨다.

<br />

### Q2. Redo Log와 Undo Log의 차이는?

| | Redo Log | Undo Log |
| --- | --- | --- |
| 목적 | **지속성(Durability)** — 장애 복구 | **원자성(Atomicity)** — 롤백, **MVCC** |
| 내용 | "무엇을 변경했는가" (변경 후) | "이전 값은 무엇이었는가" (변경 전) |
| 쓰는 시점 | 커밋 시 디스크에 순차 기록 | 변경 시 |
| 사용 | 재시작 시 커밋됐지만 반영 안 된 변경 재적용 | ROLLBACK, 과거 버전 읽기 |

**WAL (Write-Ahead Logging)**: 데이터 페이지를 디스크에 쓰기 **전에** 로그를 먼저 기록한다. 데이터 파일 갱신은 랜덤 I/O라 느리지만, 로그는 **순차 I/O라 빠르다.** 커밋 시 로그만 확실히 쓰면 지속성이 보장되므로 성능과 안정성을 동시에 얻는다.

> `innodb_flush_log_at_trx_commit` = 1(기본, 커밋마다 fsync, 가장 안전) / 2 / 0 의 트레이드오프도 물어본다.

<br />

### 공부할 것

- 버퍼 풀, Change Buffer, Adaptive Hash Index, Doublewrite Buffer
- Redo/Undo Log, WAL, 체크포인트, 크래시 리커버리
- `innodb_buffer_pool_size`, `innodb_flush_log_at_trx_commit`, `sync_binlog`
- 참고: [InnoDB 버퍼 풀 최적화](../db/mysql/innodb-buffer-pool-optimization.md)

<br />

---

## 5. 쿼리 최적화와 실행 계획

### Q1. EXPLAIN 결과에서 무엇을 보는가?

| 컬럼 | 봐야 할 것 |
| --- | --- |
| `type` | **가장 중요.** `system > const > eq_ref > ref > range > index > ALL` 순으로 나쁨. **`ALL`(풀스캔)과 `index`(인덱스 풀스캔)가 보이면 의심.** |
| `key` | 실제로 사용된 인덱스. `NULL`이면 인덱스 미사용. |
| `rows` | 옵티마이저가 읽을 것으로 추정한 행 수. 실제 결과 수와 크게 차이나면 통계가 낡았거나 인덱스가 부적절. |
| `filtered` | 조건으로 걸러진 비율(%). 낮으면 많이 읽고 조금 남긴 것. |
| `Extra` | `Using index` = 커버링(좋음) / `Using filesort`, `Using temporary` = 정렬·임시 테이블(나쁨) / `Using where` = 테이블 접근 후 필터링 |

- MySQL 8.0의 `EXPLAIN ANALYZE`는 **실제 실행 시간과 실제 행 수**를 보여줘서 추정치와 실제를 비교할 수 있다.

<br />

### Q2. N+1 문제란 무엇이고 어떻게 해결하는가?

목록 N건을 조회한 뒤, 각 건의 연관 데이터를 조회하느라 쿼리가 1 + N번 나가는 문제다. ORM의 지연 로딩(Lazy Loading)에서 주로 발생한다.

**해결 방법**

1. **JOIN FETCH / eager relation** — 한 방 쿼리로 조인해서 가져온다. 단, 1:N 조인은 행이 뻥튀기되고 페이징과 함께 쓰면 문제가 생긴다.
2. **IN 절 배치 조회 (권장)** — 부모를 먼저 조회하고 자식은 `WHERE parent_id IN (...)` 한 번으로 가져와 메모리에서 매핑한다. 쿼리 2번으로 끝난다. (DataLoader 패턴)
3. 필요한 컬럼만 뽑는 **DTO 프로젝션**.

```typescript
// N+1 발생
const orders = await orderRepo.find();                 // 1번
for (const o of orders) await o.items;                 // N번

// 해결 1: 조인
await orderRepo.find({ relations: { items: true } });

// 해결 2: 배치 조회 (1:N + 페이징에 안전)
const orders = await orderRepo.find({ take: 20 });
const items = await itemRepo.find({
  where: { orderId: In(orders.map(o => o.id)) },
});
```

<br />

### Q3. 느린 쿼리를 만나면 어떤 순서로 접근하는가?

```
1. 측정   : slow query log / performance_schema 로 실제 느린 쿼리를 특정한다. (추측 금지)
2. 분석   : EXPLAIN (ANALYZE) 로 type, key, rows, Extra 확인
3. 가설   : 인덱스 부재? 함수 적용? 정렬? 조인 순서? 데이터량?
4. 조치   : 인덱스 추가/수정 → 쿼리 재작성 → 스키마 변경 → 캐시 → 아키텍처
5. 검증   : 동일 조건으로 재측정, 쓰기 성능/다른 쿼리 영향도 확인
```

조치는 **비용이 낮은 것부터** 시도한다. 캐시는 근본 해결이 아니라 마지막 수단에 가깝다는 점을 언급하면 좋다.

<br />

### 공부할 것

- `EXPLAIN` / `EXPLAIN ANALYZE` 전 컬럼 해석
- slow query log, `pt-query-digest`, `performance_schema`
- N+1, DataLoader, 배치 사이즈
- 조인 알고리즘: Nested Loop Join, Block Nested Loop, **Hash Join(MySQL 8.0.18+)**
- 서브쿼리 vs 조인 vs `EXISTS` vs `IN`
- 참고: [쿼리 최적화](../db/mysql/query-optimization.md), [JOIN](../mysql/join.md), [COUNT](../mysql/count.md)

<br />

---

## 6. 정규화와 반정규화

### Q1. 정규화 1~3차를 설명하라.

| 단계 | 조건 | 한 줄 설명 |
| --- | --- | --- |
| 1NF | 모든 컬럼이 원자값 | 한 칸에 값 여러 개(콤마 구분, 배열) 금지 |
| 2NF | 1NF + **부분 함수 종속 제거** | 복합 PK의 일부에만 종속된 컬럼 분리 |
| 3NF | 2NF + **이행적 종속 제거** | (PK → A → B) 구조에서 B를 분리 |
| BCNF | 3NF + 모든 결정자가 후보키 | 후보키가 여러 개일 때의 예외 처리 |

**정규화의 목적**: 중복 제거 → **이상 현상(삽입/갱신/삭제 이상) 방지**, 무결성 확보.

<br />

### Q2. 반정규화는 언제 하는가?

- 조인이 너무 많아 조회 성능이 한계일 때
- 집계 값을 매번 계산하기엔 비용이 클 때 (예: `post.comment_count`)
- 통계/리포팅처럼 읽기 전용 워크로드가 분리될 때

**대가**: 중복 데이터의 **동기화 책임을 애플리케이션이 진다.** 그래서 반정규화를 말할 땐 반드시 **"어떻게 정합성을 맞출 것인가"(트리거 / 이벤트 / 배치 재계산 / 주기적 검증)** 를 같이 말해야 한다.

<br />

### 공부할 것

- 1NF~BCNF, 함수 종속성, 이상 현상 3가지
- 반정규화 기법 (컬럼 중복, 집계 컬럼, 테이블 병합/분할)
- 참고: [RDBMS](../db/rdbms.md)

<br />

---

## 7. 페이징

### Q1. OFFSET 페이징은 왜 뒤로 갈수록 느려지는가?

```sql
SELECT * FROM posts ORDER BY id DESC LIMIT 20 OFFSET 1000000;
```

**OFFSET 만큼의 행을 실제로 읽고 버리기 때문이다.** 100만 번째 페이지는 1,000,020건을 읽고 20건만 반환한다. 게다가 데이터가 중간에 삽입/삭제되면 **페이지 사이에 항목이 중복되거나 누락**된다.

### Q2. 커서(No-Offset) 페이징

```sql
-- 마지막으로 본 id를 기준으로 이어서 조회
SELECT * FROM posts WHERE id < :lastId ORDER BY id DESC LIMIT 20;
```

- 인덱스에서 시작 위치를 바로 찾아 20건만 읽으므로 **페이지 깊이와 무관하게 일정한 성능**을 낸다.
- 정렬 기준이 유니크하지 않으면 **(정렬키, PK) 복합 커서**를 쓴다.

```sql
WHERE (created_at, id) < (:lastCreatedAt, :lastId)
ORDER BY created_at DESC, id DESC
LIMIT 20;
```

- 한계: **임의 페이지 번호로 점프 불가**, 전체 페이지 수 표시가 어렵다. → 무한 스크롤/피드에 적합.

### Q3. OFFSET을 꼭 써야 한다면?

**커버링 인덱스로 PK만 먼저 페이징하고, 그 PK로 조인**한다.

```sql
SELECT p.* FROM posts p
JOIN (
  SELECT id FROM posts ORDER BY id DESC LIMIT 20 OFFSET 1000000
) t ON p.id = t.id;
```

버리는 100만 건을 **인덱스만 읽고 넘기므로** 행 전체를 읽는 것보다 훨씬 싸다.

> 대용량 `COUNT(*)`도 같이 물어본다. → 근사치 사용(`information_schema.TABLES`), 카운트 캐싱, "다음 페이지 존재 여부"만 확인(`LIMIT n+1`)으로 대체.

**공부할 것**: 참고 [페이징](../mysql/page.md), [COUNT](../mysql/count.md)

<br />

---

## 8. 커넥션 풀

### Q1. 커넥션 풀은 왜 필요한가?

DB 커넥션 생성은 TCP 핸드셰이크 + 인증 + 세션 초기화가 필요한 **비싼 작업**이다. 미리 만들어 재사용해 지연을 없애고, 동시에 **DB로 가는 동시 커넥션 수의 상한을 두어 DB를 보호**한다.

### Q2. 풀 사이즈는 어떻게 정하는가?

- 무조건 크게 잡으면 **DB의 컨텍스트 스위칭과 락 경합이 심해져 오히려 느려진다.**
- 널리 쓰이는 출발점: `pool size = (core_count * 2) + effective_spindle_count` (HikariCP 가이드)
- 실제로는 **부하 테스트로 결정**하고, `대기 시간`, `활성 커넥션 수`, `DB max_connections` 를 함께 본다.
- 중요: **애플리케이션 인스턴스 수 × 풀 사이즈 ≤ DB `max_connections`** 여야 한다. 오토스케일링 시 이걸 놓쳐 커넥션이 터지는 사고가 흔하다.

### Q3. "커넥션 풀 고갈" 장애는 왜 나는가?

```
느린 쿼리 / 긴 트랜잭션 / 외부 API 호출이 트랜잭션 안에 있음
   → 커넥션 반납 지연
   → 풀 고갈
   → 모든 요청이 커넥션 대기 (타임아웃)
   → 서비스 전체 장애
```

- 예방: 트랜잭션 짧게, statement timeout / lock wait timeout 설정, 슬로우 쿼리 모니터링, 커넥션 누수 감지(`leakDetectionThreshold`), 서킷 브레이커.

**공부할 것**: HikariCP / TypeORM `poolSize` / `pg-pool` 설정, `max_connections`, `wait_timeout`, 커넥션 누수 탐지

<br />

---

## 9. 복제 · 파티셔닝 · 샤딩

### Q1. 레플리케이션(복제)의 구조와 문제점은?

```
Client ─ Write ─→ [Source(Master)] ─── binlog ───→ [Replica 1] ─ Read
                                     └───────────→ [Replica 2] ─ Read
```

- 목적: **읽기 부하 분산**, 장애 대비(HA), 백업/분석 분리.
- 비동기 복제가 기본이라 **복제 지연(Replication Lag)** 이 발생한다.
- **핵심 문제**: 쓰기 직후 레플리카에서 읽으면 **방금 쓴 데이터가 안 보인다** (Read-Your-Writes 위반).
  - 해결: 쓰기 직후 일정 시간은 소스에서 읽기, 세션 단위 라우팅, `Semi-sync` 복제, 지연 모니터링 후 라우팅 제외.

### Q2. 파티셔닝과 샤딩의 차이는?

| | 파티셔닝 (Partitioning) | 샤딩 (Sharding) |
| --- | --- | --- |
| 범위 | **한 DB 서버 안**에서 테이블을 분할 | **여러 DB 서버**로 데이터 분산 |
| 목적 | 큰 테이블 관리/조회 효율, 오래된 데이터 삭제 용이 | 쓰기 확장(Scale-out), 용량 한계 돌파 |
| 방식 | RANGE / LIST / HASH / KEY | 샤드 키 기반 라우팅 |
| 난이도 | 낮음 | 매우 높음 |

**샤딩의 대가 (반드시 언급)**

- **샤드 간 JOIN과 트랜잭션이 불가능**하다 → 애플리케이션이 조합해야 한다.
- **샤드 키 선택이 곧 설계**다. 잘못 고르면 **핫스팟**(특정 샤드에 몰림)이 생기고 바꾸기 매우 어렵다.
- **리밸런싱**이 어렵다 → Consistent Hashing이나 논리 샤드(가상 버킷)를 미리 둔다.
- 그래서 순서는 **인덱스/쿼리 튜닝 → 캐시 → 읽기 복제본 → 스케일업 → 파티셔닝 → 샤딩**이다. 샤딩은 마지막 카드다.

**공부할 것**: binlog(Row/Statement/Mixed), 복제 지연 대응, GTID, Consistent Hashing, 핫스팟, CDC(Debezium)

<br />

---

## 10. RDB vs NoSQL

### Q1. 어떤 기준으로 선택하는가?

| 기준 | RDB | NoSQL |
| --- | --- | --- |
| 스키마 | 고정, 강한 무결성 | 유연, 스키마리스 |
| 관계 | JOIN으로 표현 | 비정규화/임베딩 |
| 트랜잭션 | 강력한 ACID | 제한적 (문서 단위 등) |
| 확장 | 수직 확장 위주 | 수평 확장 용이 |
| 적합 | 금융/주문/정산 등 정합성이 생명 | 로그, 세션, 피드, 대용량 시계열, 캐시 |

**답변 포인트**: "요즘 NoSQL이 좋아서"가 아니라 **접근 패턴(Access Pattern)** 이 기준이다. 관계를 여러 방향으로 탐색해야 하면 RDB, 정해진 키로 대량 읽기/쓰기를 하면 NoSQL이 유리하다. 실무에서는 대부분 **RDB를 주 저장소로 두고 NoSQL/캐시를 보조로 쓰는 폴리글랏 구성**을 쓴다.

### Q2. CAP 이론을 설명하라.

분산 시스템은 **Consistency(일관성) / Availability(가용성) / Partition Tolerance(분할 내성)** 중 셋을 동시에 만족할 수 없다.

- 네트워크 분할(P)은 **선택 사항이 아니라 현실**이므로, 실제 선택은 **분할이 일어났을 때 C를 버릴 것인가 A를 버릴 것인가**다.
- CP: 정합성 우선 (HBase, ZooKeeper, MongoDB 기본) — 분할 시 응답 거부
- AP: 가용성 우선 (Cassandra, DynamoDB) — 분할 시에도 응답, 나중에 수렴(Eventual Consistency)
- 확장: **PACELC** — 분할이 없을 때(E)도 **지연(L) vs 일관성(C)** 을 선택해야 한다.

**공부할 것**: CAP/PACELC, BASE vs ACID, Eventual Consistency, 문서/키값/컬럼패밀리/그래프 DB 종류 — 참고 [MongoDB](../db/nosql/mongodb/index.md), [ClickHouse](../db/clickhouse.md)

<br />

---

## 11. 캐시와 DB 일관성

### Q1. 캐시 갱신 시 왜 "삭제(invalidate)"가 "갱신(update)"보다 나은가?

동시성 상황에서 update 방식은 **오래된 값이 최종적으로 캐시에 남는 순서 역전**이 생길 수 있다. 삭제는 다음 조회에서 DB의 최신 값을 다시 채우므로 안전하다.

### Q2. DB를 먼저 쓸까, 캐시를 먼저 지울까?

**Cache Aside 기준: DB 갱신 → 캐시 삭제 순서**가 표준이다. 그래도 드물게 불일치가 나는 케이스가 있어(읽기 스레드가 DB를 읽은 직후 캐시에 넣는 타이밍) **짧은 TTL을 안전망으로 두거나, 지연 이중 삭제(delayed double delete)** 를 쓴다.

### Q3. 캐시 관련 3대 장애

| 현상 | 설명 | 대응 |
| --- | --- | --- |
| Cache Stampede | 인기 키 만료 순간 요청이 DB로 몰림 | 분산 락, 요청 병합(Request Coalescing), 논리적 만료 |
| Cache Penetration | 존재하지 않는 키를 계속 조회해 DB까지 도달 | Null 캐싱, Bloom Filter |
| Cache Avalanche | 대량 키가 동시에 만료 | TTL에 Jitter 추가 |

**공부할 것**: 참고 [캐시](../cache/index.md), [캐싱 전략](../cache/strategy.md), [Redis](../redis/redis.md)

<br />

---

## 12. 실무 경험 질문

지식보다 이쪽에서 당락이 갈린다. **각 항목마다 수치와 함께** 답변을 미리 준비한다.

- 쿼리 성능을 개선한 경험이 있는가? **무엇을 어떻게 측정했고, 몇 ms에서 몇 ms가 되었는가?**
- 인덱스를 설계할 때 어떤 기준으로 컬럼과 순서를 정했는가?
- 데드락이나 락 대기 장애를 겪은 적이 있는가? 원인을 어떻게 찾았는가?
- 동시성 이슈(중복 결제, 재고 초과 판매)를 어떻게 막았는가?
- 대용량 테이블에 인덱스를 추가하거나 컬럼을 변경해야 할 때 어떻게 하는가?
  → **온라인 DDL**, `pt-online-schema-change` / `gh-ost`, 새 테이블 생성 후 백필 & 스위칭, 배포 시간대 고려
- 마이그레이션을 무중단으로 하려면? → **확장-축소(Expand-Contract) 패턴**: 컬럼 추가 → 양쪽 쓰기 → 백필 → 읽기 전환 → 옛 컬럼 제거
- 데이터 정합성이 깨진 적이 있는가? 어떻게 발견하고 복구했는가?

<br />

---

## 13. 학습 체크리스트

**Level 1 — 말할 수 있어야 함**

- [ ] 인덱스가 빠른 이유를 B+Tree 구조로 설명할 수 있다
- [ ] 클러스터드 / 세컨더리 인덱스 차이와 북마크 룩업을 설명할 수 있다
- [ ] 복합 인덱스 순서 규칙(Leftmost, 범위 조건 뒤로)을 설명할 수 있다
- [ ] ACID 각각의 구현 수단(Undo/Redo/WAL/락)을 말할 수 있다
- [ ] 격리 수준 4단계와 이상 현상 3가지를 표로 그릴 수 있다
- [ ] 정규화 1~3차를 예시로 설명할 수 있다

**Level 2 — 직접 해봐야 함**

- [ ] 터미널 2개로 격리 수준별 이상 현상을 재현해봤다
- [ ] 일부러 데드락을 만들고 `SHOW ENGINE INNODB STATUS`로 분석해봤다
- [ ] 100만 건 더미 데이터로 인덱스 유무의 `EXPLAIN`과 실행 시간을 비교해봤다
- [ ] OFFSET 페이징과 커서 페이징의 성능 차이를 직접 측정해봤다
- [ ] N+1을 발생시키고 쿼리 로그로 확인한 뒤 해결해봤다
- [ ] 커버링 인덱스를 만들어 `Using index`가 뜨는 것을 확인했다

**Level 3 — 설계할 수 있어야 함**

- [ ] 주어진 요구사항에서 테이블 스키마와 인덱스를 설계할 수 있다
- [ ] 선착순 쿠폰 발급 시스템을 동시성 관점에서 설계할 수 있다
- [ ] 읽기 부하가 커질 때의 확장 순서를 근거와 함께 제시할 수 있다
- [ ] 무중단 스키마 마이그레이션 절차를 설명할 수 있다

<br />

## 참고 자료

- Real MySQL 8.0 (백은빈, 이성욱) — 면접 대비 1순위
- Database Internals (Alex Petrov)
- Designing Data-Intensive Applications (Martin Kleppmann) — 5~9장
- MySQL 공식 문서: InnoDB Locking and Transaction Model
- 사내 문서: [MySQL](../mysql/index.md), [DB](../db/rdbms.md), [Cache](../cache/index.md)
- 함께 보기: [Redis/Valkey 면접](./redis.md), [MQ 면접](./mq.md), [MSA 면접](./msa.md)
