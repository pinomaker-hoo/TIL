# MySQL 인덱스 최적화

> 인덱스는 MySQL 성능 최적화의 가장 기본이자 핵심이다. 적절한 인덱스 설계만으로 쿼리 성능이 수십~수백 배 향상될 수 있다.

## 목차

1. [인덱스의 동작 원리](#1-인덱스의-동작-원리)
2. [인덱스 종류](#2-인덱스-종류)
3. [복합 인덱스 설계](#3-복합-인덱스-설계)
4. [커버링 인덱스](#4-커버링-인덱스)
5. [인덱스가 사용되지 않는 경우](#5-인덱스가-사용되지-않는-경우)
6. [EXPLAIN으로 인덱스 분석](#6-explain으로-인덱스-분석)
7. [인덱스 관리 및 모니터링](#7-인덱스-관리-및-모니터링)
8. [실전 최적화 사례](#8-실전-최적화-사례)

---

## 1. 인덱스의 동작 원리

### B+Tree 구조

MySQL InnoDB의 인덱스는 **B+Tree** 자료구조를 사용한다.

```
                    ┌───────────────┐
                    │  Root Node    │
                    │  [30 | 60]    │
                    └───┬───┬───┬───┘
                        │   │   │
          ┌─────────────┘   │   └─────────────┐
          ▼                 ▼                 ▼
    ┌──────────┐     ┌──────────┐     ┌──────────┐
    │ [10|20]  │     │ [40|50]  │     │ [70|80]  │
    └──┬──┬──┬─┘     └──┬──┬──┬─┘     └──┬──┬──┬─┘
       │  │  │          │  │  │          │  │  │
       ▼  ▼  ▼          ▼  ▼  ▼          ▼  ▼  ▼
    [Leaf Nodes - 실제 데이터 포인터 또는 데이터]
    ← 리프 노드들은 서로 연결 리스트로 연결 →
```

- **루트 노드 → 브랜치 노드 → 리프 노드** 순으로 탐색
- 리프 노드끼리 **양방향 링크드 리스트**로 연결되어 범위 검색이 효율적
- 탐색 시간 복잡도: **O(log N)**

### 클러스터드 인덱스 vs 세컨더리 인덱스

```
클러스터드 인덱스 (Primary Key):
┌────────────────────────────────────────────┐
│  B+Tree 리프 노드에 실제 행 데이터가 저장     │
│  PK=1 → [id=1, name="홍길동", age=30, ...]  │
│  PK=2 → [id=2, name="김철수", age=25, ...]  │
│  테이블당 1개만 존재                           │
└────────────────────────────────────────────┘

세컨더리 인덱스 (보조 인덱스):
┌────────────────────────────────────────────┐
│  B+Tree 리프 노드에 PK 값을 저장              │
│  email="hong@..." → PK=1                   │
│  email="kim@..." → PK=2                    │
│  → PK로 클러스터드 인덱스를 다시 조회 (랜덤 I/O) │
└────────────────────────────────────────────┘
```

세컨더리 인덱스 조회 과정:
1. 세컨더리 인덱스에서 조건에 맞는 PK를 찾는다
2. PK로 클러스터드 인덱스를 조회하여 실제 데이터를 가져온다
3. 이 두 번째 조회를 **랜덤 I/O**라 하며, 대량 조회 시 성능 병목이 된다

---

## 2. 인덱스 종류

### B+Tree 인덱스 (기본)

```sql
-- 단일 컬럼 인덱스
CREATE INDEX idx_users_email ON users (email);

-- 유니크 인덱스
CREATE UNIQUE INDEX idx_users_email ON users (email);

-- 복합 인덱스
CREATE INDEX idx_orders_user_date ON orders (user_id, order_date);

-- 내림차순 인덱스 (MySQL 8.0+)
CREATE INDEX idx_orders_date_desc ON orders (order_date DESC);
```

### 전문 검색 인덱스 (FULLTEXT)

```sql
CREATE FULLTEXT INDEX idx_articles_content ON articles (title, content);

-- 자연어 모드 검색
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('MySQL 최적화' IN NATURAL LANGUAGE MODE);

-- 불리언 모드 검색
SELECT * FROM articles
WHERE MATCH(title, content) AGAINST('+MySQL -Oracle' IN BOOLEAN MODE);
```

### 공간 인덱스 (SPATIAL)

```sql
CREATE SPATIAL INDEX idx_stores_location ON stores (location);

-- 반경 검색
SELECT name, ST_Distance_Sphere(location, ST_GeomFromText('POINT(127.0 37.5)')) AS dist
FROM stores
WHERE ST_Distance_Sphere(location, ST_GeomFromText('POINT(127.0 37.5)')) < 1000;
```

### 함수 기반 인덱스 (MySQL 8.0+)

```sql
-- 표현식 인덱스
CREATE INDEX idx_users_email_lower ON users ((LOWER(email)));
CREATE INDEX idx_orders_year ON orders ((YEAR(order_date)));

-- JSON 값에 대한 인덱스
CREATE INDEX idx_users_city ON users ((CAST(metadata->>'$.city' AS CHAR(50))));
```

### 보이지 않는 인덱스 (Invisible Index, MySQL 8.0+)

```sql
-- 인덱스를 삭제하지 않고 비활성화하여 영향도 테스트
ALTER TABLE users ALTER INDEX idx_users_name INVISIBLE;

-- 쿼리 성능 확인 후 다시 활성화
ALTER TABLE users ALTER INDEX idx_users_name VISIBLE;

-- 인덱스를 invisible 상태로 생성
CREATE INDEX idx_test ON users (name) INVISIBLE;
```

---

## 3. 복합 인덱스 설계

### 왼쪽 접두사 규칙 (Leftmost Prefix Rule)

복합 인덱스 `(a, b, c)`가 있을 때, 사용 가능한 조합:

```
인덱스: (a, b, c)

✅ WHERE a = 1                        → a 사용
✅ WHERE a = 1 AND b = 2              → a, b 사용
✅ WHERE a = 1 AND b = 2 AND c = 3    → a, b, c 사용
✅ WHERE a = 1 AND c = 3              → a만 사용 (c는 건너뜀)
❌ WHERE b = 2                        → 인덱스 미사용
❌ WHERE b = 2 AND c = 3              → 인덱스 미사용
❌ WHERE c = 3                        → 인덱스 미사용
```

### 복합 인덱스 설계 원칙

```sql
-- 쿼리 패턴:
-- SELECT * FROM orders WHERE status = 'completed' AND user_id = 123 ORDER BY created_at DESC

-- 원칙 1: 등호(=) 조건 컬럼을 앞에 배치
-- 원칙 2: 정렬(ORDER BY) 컬럼을 그 다음에 배치
-- 원칙 3: 범위 조건 컬럼을 마지막에 배치

-- 좋은 인덱스 (등호 → 정렬 → 범위)
CREATE INDEX idx_orders_optimal ON orders (status, user_id, created_at);
```

### 인덱스 선택도 (Selectivity)

선택도가 높은(고유 값이 많은) 컬럼을 앞에 배치한다.

```sql
-- 선택도 확인
SELECT
    COUNT(DISTINCT status) / COUNT(*) AS status_selectivity,     -- 낮음 (값이 몇 개 안 됨)
    COUNT(DISTINCT user_id) / COUNT(*) AS user_id_selectivity,   -- 높음
    COUNT(DISTINCT email) / COUNT(*) AS email_selectivity        -- 매우 높음
FROM orders;

-- 선택도가 높은 컬럼을 앞에 배치
CREATE INDEX idx_orders ON orders (user_id, status);   -- ✅
-- CREATE INDEX idx_orders ON orders (status, user_id); -- △ (status 값이 적으면 비효율)
```

### 정렬과 인덱스

```sql
-- 인덱스: (user_id, created_at)
-- ✅ 인덱스로 정렬 가능 (filesort 없음)
SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at DESC;

-- ❌ 인덱스로 정렬 불가 (filesort 발생)
SELECT * FROM orders WHERE user_id > 1 ORDER BY created_at DESC;
-- → 범위 조건 이후의 컬럼은 인덱스 정렬을 활용할 수 없음

-- ❌ 혼합 정렬 방향 (MySQL 8.0 이전)
SELECT * FROM orders ORDER BY user_id ASC, created_at DESC;
-- MySQL 8.0+에서는 내림차순 인덱스로 해결:
CREATE INDEX idx ON orders (user_id ASC, created_at DESC);
```

---

## 4. 커버링 인덱스

쿼리에 필요한 모든 컬럼이 인덱스에 포함되어 있으면, 테이블 데이터에 접근하지 않고 **인덱스만으로 결과를 반환**한다.

```sql
-- 인덱스: (user_id, status, amount)
CREATE INDEX idx_orders_cover ON orders (user_id, status, amount);

-- ✅ 커버링 인덱스 (Extra: Using index)
SELECT status, amount FROM orders WHERE user_id = 123;
-- → 인덱스 리프 노드에 status, amount가 이미 있으므로 테이블 접근 불필요

-- ❌ 커버링 인덱스 아님 (SELECT *에 인덱스에 없는 컬럼 포함)
SELECT * FROM orders WHERE user_id = 123;
-- → 인덱스에서 PK를 찾고, 클러스터드 인덱스에서 전체 행을 다시 조회
```

EXPLAIN 결과에서 `Extra: Using index`가 표시되면 커버링 인덱스가 사용된 것이다.

```sql
EXPLAIN SELECT status, amount FROM orders WHERE user_id = 123;
-- +----+-------+------+---------+------+-------------+
-- | id | type  | key  | key_len | rows | Extra       |
-- +----+-------+------+---------+------+-------------+
-- |  1 | ref   | idx  | 8       |   15 | Using index | ← 커버링 인덱스
-- +----+-------+------+---------+------+-------------+
```

---

## 5. 인덱스가 사용되지 않는 경우

### 컬럼에 함수/연산 적용

```sql
-- ❌ 인덱스 미사용 (컬럼에 함수 적용)
SELECT * FROM users WHERE YEAR(created_at) = 2024;
SELECT * FROM users WHERE LOWER(email) = 'hong@example.com';

-- ✅ 인덱스 사용
SELECT * FROM users WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01';
SELECT * FROM users WHERE email = 'hong@example.com';  -- 대소문자 구분 불필요 시 collation 활용

-- ✅ MySQL 8.0+: 함수 기반 인덱스
CREATE INDEX idx_year ON users ((YEAR(created_at)));
```

### 암시적 타입 변환

```sql
-- phone_number가 VARCHAR 타입일 때
-- ❌ 인덱스 미사용 (숫자 → 문자 암시적 변환)
SELECT * FROM users WHERE phone_number = 01012345678;

-- ✅ 인덱스 사용 (타입 일치)
SELECT * FROM users WHERE phone_number = '01012345678';
```

### LIKE 와일드카드 선행

```sql
-- ❌ 인덱스 미사용 (앞에 와일드카드)
SELECT * FROM users WHERE name LIKE '%길동';
SELECT * FROM users WHERE name LIKE '%길%';

-- ✅ 인덱스 사용 (접두사 매칭)
SELECT * FROM users WHERE name LIKE '홍%';
```

### OR 조건

```sql
-- ❌ 인덱스 비효율적
SELECT * FROM users WHERE name = '홍길동' OR age = 30;
-- → name에 인덱스가 있어도 age 조건 때문에 전체 스캔 가능

-- ✅ UNION으로 분리
SELECT * FROM users WHERE name = '홍길동'
UNION ALL
SELECT * FROM users WHERE age = 30 AND name != '홍길동';
```

### NOT, != 연산

```sql
-- ❌ 인덱스 비효율적 (대부분의 행을 스캔해야 함)
SELECT * FROM users WHERE status != 'deleted';

-- ✅ 인덱스 효율적 (소수의 행만 조회)
SELECT * FROM users WHERE status = 'active';
```

---

## 6. EXPLAIN으로 인덱스 분석

### 기본 사용법

```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 123 AND status = 'completed';
```

### 주요 컬럼 해석

| 컬럼 | 설명 | 좋은 값 |
|------|------|--------|
| `type` | 접근 방식 | const > eq_ref > ref > range > index > ALL |
| `key` | 사용된 인덱스 | NULL이면 인덱스 미사용 |
| `key_len` | 인덱스 사용 길이 | 복합 인덱스에서 몇 개 컬럼이 사용되었는지 판단 |
| `rows` | 예상 스캔 행 수 | 적을수록 좋음 |
| `filtered` | 필터링 비율 | 100%에 가까울수록 좋음 |
| `Extra` | 추가 정보 | Using index (커버링), Using filesort (정렬 필요) |

### type 값의 의미

```
const      → PK 또는 UNIQUE로 1행 조회 (최고 성능)
eq_ref     → JOIN에서 PK/UNIQUE로 1행 매칭
ref        → 인덱스로 여러 행 조회 (등호 조건)
range      → 인덱스 범위 스캔 (BETWEEN, >, <, IN)
index      → 인덱스 전체 스캔 (Full Index Scan)
ALL        → 테이블 전체 스캔 (Full Table Scan) ← 최악
```

### EXPLAIN ANALYZE (MySQL 8.0.18+)

```sql
EXPLAIN ANALYZE
SELECT u.name, COUNT(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at >= '2024-01-01'
GROUP BY u.name
ORDER BY order_count DESC
LIMIT 10;

-- 실제 실행 시간과 행 수를 보여줌
-- → (actual time=0.5..15.2 rows=10 loops=1)
```

---

## 7. 인덱스 관리 및 모니터링

### 사용되지 않는 인덱스 찾기

```sql
-- performance_schema에서 인덱스 사용 통계 확인
SELECT
    object_schema AS db_name,
    object_name AS table_name,
    index_name,
    count_star AS total_access,
    count_read AS reads,
    count_write AS writes
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE object_schema = 'mydb'
    AND index_name IS NOT NULL
    AND count_star = 0
ORDER BY object_name;
```

### 중복 인덱스 찾기

```sql
-- 중복 인덱스 확인 (sys 스키마)
SELECT * FROM sys.schema_redundant_indexes WHERE table_schema = 'mydb';

-- 예: (a, b) 인덱스가 있을 때 (a) 인덱스는 중복
-- → (a, b)가 (a) 단독 조회도 커버하기 때문
```

### 인덱스 크기 확인

```sql
SELECT
    table_name,
    index_name,
    ROUND(stat_value * @@innodb_page_size / 1024 / 1024, 2) AS size_mb
FROM mysql.innodb_index_stats
WHERE database_name = 'mydb'
    AND stat_name = 'size'
ORDER BY stat_value DESC;
```

---

## 8. 실전 최적화 사례

### 사례 1: 페이지네이션 최적화

```sql
-- ❌ OFFSET이 커지면 매우 느려짐
SELECT * FROM articles ORDER BY id DESC LIMIT 20 OFFSET 100000;
-- → 100,020개의 행을 읽고 100,000개를 버림

-- ✅ 커서 기반 페이지네이션 (이전 페이지의 마지막 id를 기준)
SELECT * FROM articles WHERE id < 900000 ORDER BY id DESC LIMIT 20;
-- → 인덱스를 타고 바로 해당 위치로 이동

-- ✅ 디퍼드 조인 (Deferred Join)
SELECT a.* FROM articles a
INNER JOIN (
    SELECT id FROM articles ORDER BY id DESC LIMIT 20 OFFSET 100000
) AS t ON a.id = t.id;
-- → 서브쿼리에서 PK만 커버링 인덱스로 가져온 후 JOIN
```

### 사례 2: COUNT 쿼리 최적화

```sql
-- ❌ 느림 (조건이 있는 COUNT)
SELECT COUNT(*) FROM orders WHERE status = 'pending' AND created_at >= '2024-01-01';

-- ✅ 커버링 인덱스 활용
CREATE INDEX idx_orders_status_date ON orders (status, created_at);
SELECT COUNT(*) FROM orders WHERE status = 'pending' AND created_at >= '2024-01-01';
-- → Using index (테이블 접근 없이 인덱스만으로 COUNT)
```

### 사례 3: ORDER BY + LIMIT 최적화

```sql
-- ❌ filesort 발생 (인덱스 없는 정렬)
SELECT * FROM products WHERE category_id = 5 ORDER BY price ASC LIMIT 10;

-- ✅ 복합 인덱스로 filesort 제거
CREATE INDEX idx_products_cat_price ON products (category_id, price);
SELECT * FROM products WHERE category_id = 5 ORDER BY price ASC LIMIT 10;
-- → 인덱스 순서대로 10개만 읽고 바로 반환
```

---

## 핵심 요약

- InnoDB는 **B+Tree** 기반의 클러스터드 인덱스와 세컨더리 인덱스를 사용한다
- 복합 인덱스는 **왼쪽 접두사 규칙**을 따르며, **등호 → 정렬 → 범위** 순서로 설계한다
- **커버링 인덱스**를 활용하면 테이블 접근 없이 인덱스만으로 쿼리를 처리할 수 있다
- 컬럼에 **함수 적용, 암시적 타입 변환, LIKE '%...'** 등은 인덱스를 무력화한다
- **EXPLAIN ANALYZE**로 실제 실행 계획과 소요 시간을 확인하여 인덱스 효과를 검증한다
- 사용되지 않는 인덱스와 중복 인덱스를 주기적으로 정리하여 쓰기 성능을 유지한다

## 참고 자료

- [MySQL 공식 문서 - Optimization and Indexes](https://dev.mysql.com/doc/refman/8.0/en/optimization-indexes.html)
- [MySQL 공식 문서 - EXPLAIN Output Format](https://dev.mysql.com/doc/refman/8.0/en/explain-output.html)
- [Use The Index, Luke](https://use-the-index-luke.com/)
