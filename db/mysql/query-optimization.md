# MySQL 쿼리 최적화

> 쿼리 최적화는 동일한 결과를 더 적은 리소스로, 더 빠르게 반환하도록 SQL 문을 개선하는 과정이다. 인덱스와 함께 MySQL 성능 튜닝의 양대 축을 이룬다.

## 목차

1. [쿼리 실행 과정 이해](#1-쿼리-실행-과정-이해)
2. [슬로우 쿼리 분석](#2-슬로우-쿼리-분석)
3. [SELECT 쿼리 최적화](#3-select-쿼리-최적화)
4. [JOIN 최적화](#4-join-최적화)
5. [서브쿼리 최적화](#5-서브쿼리-최적화)
6. [GROUP BY / ORDER BY 최적화](#6-group-by--order-by-최적화)
7. [INSERT / UPDATE / DELETE 최적화](#7-insert--update--delete-최적화)
8. [실전 쿼리 리팩토링](#8-실전-쿼리-리팩토링)

---

## 1. 쿼리 실행 과정 이해

MySQL 서버가 쿼리를 처리하는 과정을 이해하면 병목 지점을 파악하기 쉽다.

```
클라이언트 쿼리
       ↓
┌──────────────────────┐
│  1. 파서 (Parser)     │  → SQL 문법 검증, 파스 트리 생성
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  2. 전처리기          │  → 테이블/컬럼 존재 여부, 권한 확인
│    (Preprocessor)    │
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  3. 옵티마이저        │  → 실행 계획 수립 (인덱스 선택, JOIN 순서 결정)
│    (Optimizer)       │  → 비용 기반 최적화 (Cost-Based Optimization)
└──────────┬───────────┘
           ↓
┌──────────────────────┐
│  4. 실행 엔진         │  → 스토리지 엔진 호출, 결과 반환
│    (Execution Engine)│
└──────────────────────┘
```

옵티마이저는 **비용 기반(Cost-Based)**으로 동작하며, 통계 정보를 바탕으로 가장 비용이 낮은 실행 계획을 선택한다.

---

## 2. 슬로우 쿼리 분석

### 슬로우 쿼리 로그 설정

```sql
-- 슬로우 쿼리 로그 활성화
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;              -- 1초 이상 쿼리 기록
SET GLOBAL slow_query_log_file = '/var/log/mysql/slow.log';

-- 인덱스 미사용 쿼리도 기록
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

```ini
# my.cnf (영구 설정)
[mysqld]
slow_query_log = 1
long_query_time = 1
slow_query_log_file = /var/log/mysql/slow.log
log_queries_not_using_indexes = 1
```

### mysqldumpslow (슬로우 쿼리 분석 도구)

```bash
# 실행 시간이 긴 순서로 상위 10개
mysqldumpslow -s t -t 10 /var/log/mysql/slow.log

# 실행 횟수가 많은 순서로
mysqldumpslow -s c -t 10 /var/log/mysql/slow.log
```

### SHOW PROFILE

```sql
-- 프로파일링 활성화
SET profiling = 1;

-- 쿼리 실행
SELECT * FROM orders WHERE user_id = 123;

-- 프로파일 확인
SHOW PROFILES;
SHOW PROFILE FOR QUERY 1;

-- 상세 프로파일 (CPU, I/O 포함)
SHOW PROFILE CPU, BLOCK IO FOR QUERY 1;
```

---

## 3. SELECT 쿼리 최적화

### SELECT * 지양

```sql
-- ❌ 모든 컬럼 조회 (불필요한 데이터 전송 + 커버링 인덱스 불가)
SELECT * FROM users WHERE age >= 20;

-- ✅ 필요한 컬럼만 조회
SELECT id, name, email FROM users WHERE age >= 20;
```

### WHERE 조건 최적화

```sql
-- ❌ 컬럼에 연산 적용 (인덱스 무력화)
SELECT * FROM orders WHERE amount * 1.1 > 50000;
SELECT * FROM users WHERE DATE(created_at) = '2024-03-15';

-- ✅ 상수에 연산 적용 (인덱스 활용)
SELECT * FROM orders WHERE amount > 50000 / 1.1;
SELECT * FROM users
WHERE created_at >= '2024-03-15 00:00:00'
  AND created_at < '2024-03-16 00:00:00';
```

### LIMIT 활용

```sql
-- ❌ 존재 여부 확인에 COUNT 사용
SELECT COUNT(*) FROM users WHERE email = 'hong@example.com';

-- ✅ LIMIT 1로 존재 여부만 확인
SELECT 1 FROM users WHERE email = 'hong@example.com' LIMIT 1;

-- ✅ EXISTS 사용
SELECT EXISTS(SELECT 1 FROM users WHERE email = 'hong@example.com');
```

### IN 절 최적화

```sql
-- ❌ IN 절에 너무 많은 값 (수만 개)
SELECT * FROM users WHERE id IN (1, 2, 3, ..., 100000);

-- ✅ 임시 테이블 활용
CREATE TEMPORARY TABLE tmp_ids (id BIGINT PRIMARY KEY);
INSERT INTO tmp_ids VALUES (1), (2), (3), ...;
SELECT u.* FROM users u INNER JOIN tmp_ids t ON u.id = t.id;

-- ✅ 범위로 변환 가능하면 BETWEEN 사용
SELECT * FROM users WHERE id BETWEEN 1 AND 100000;
```

---

## 4. JOIN 최적화

### Nested Loop Join 이해

MySQL InnoDB는 기본적으로 **Nested Loop Join**을 사용한다.

```
외부 테이블 (드라이빙 테이블)의 각 행에 대해
  → 내부 테이블 (드리븐 테이블)에서 매칭되는 행을 검색

성능 = 외부 테이블 행 수 × 내부 테이블 검색 비용
```

### JOIN 순서 최적화

```sql
-- MySQL 옵티마이저가 JOIN 순서를 자동 결정하지만,
-- 작은 결과 집합이 드라이빙 테이블이 되도록 유도

-- ✅ 작은 테이블(또는 필터링 후 적은 행)이 드라이빙 테이블
SELECT o.*
FROM orders o                           -- 필터링으로 적은 행
INNER JOIN users u ON u.id = o.user_id  -- PK로 매칭 (빠름)
WHERE o.status = 'pending'              -- orders를 먼저 필터링
  AND o.created_at >= '2024-01-01';
```

### JOIN에서 인덱스 활용

```sql
-- 드리븐 테이블의 JOIN 컬럼에 반드시 인덱스 필요
-- ❌ orders.user_id에 인덱스가 없으면 매번 전체 스캔
SELECT u.name, o.amount
FROM users u
INNER JOIN orders o ON o.user_id = u.id;

-- ✅ JOIN 컬럼에 인덱스 생성
CREATE INDEX idx_orders_user_id ON orders (user_id);
```

### Block Nested Loop → Hash Join (MySQL 8.0.18+)

```sql
-- MySQL 8.0.18+에서 인덱스가 없는 JOIN은 Hash Join으로 실행
-- → BNL보다 성능이 크게 향상

-- 옵티마이저 힌트로 Hash Join 강제
SELECT /*+ HASH_JOIN(t1, t2) */ *
FROM t1 INNER JOIN t2 ON t1.col = t2.col;
```

### 불필요한 JOIN 제거

```sql
-- ❌ 사용하지 않는 테이블까지 JOIN
SELECT o.id, o.amount
FROM orders o
INNER JOIN users u ON u.id = o.user_id        -- users의 컬럼을 사용하지 않음
INNER JOIN products p ON p.id = o.product_id  -- products의 컬럼을 사용하지 않음
WHERE o.status = 'pending';

-- ✅ 필요한 JOIN만 유지 (외래키 유효성이 보장되는 경우)
SELECT o.id, o.amount
FROM orders o
WHERE o.status = 'pending';
```

---

## 5. 서브쿼리 최적화

### 상관 서브쿼리 → JOIN 변환

```sql
-- ❌ 상관 서브쿼리 (외부 행마다 서브쿼리 실행)
SELECT *
FROM users u
WHERE (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) > 5;

-- ✅ JOIN + GROUP BY로 변환
SELECT u.*
FROM users u
INNER JOIN (
    SELECT user_id, COUNT(*) AS cnt
    FROM orders
    GROUP BY user_id
    HAVING cnt > 5
) o ON o.user_id = u.id;

-- ✅ EXISTS 활용 (단순 존재 여부)
SELECT *
FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

### IN 서브쿼리

```sql
-- MySQL 5.6 이전에서는 IN 서브쿼리가 비효율적이었으나,
-- MySQL 5.6+에서는 세미조인 최적화로 자동 변환됨

-- 기본 형태 (옵티마이저가 자동 최적화)
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders WHERE amount > 10000);

-- 옵티마이저가 자동으로 아래와 유사하게 변환:
-- SELECT u.* FROM users u SEMI JOIN orders o ON u.id = o.user_id WHERE o.amount > 10000;
```

### 스칼라 서브쿼리 최적화

```sql
-- ❌ SELECT 절의 스칼라 서브쿼리 (행마다 실행)
SELECT
    u.name,
    (SELECT COUNT(*) FROM orders o WHERE o.user_id = u.id) AS order_count,
    (SELECT MAX(amount) FROM orders o WHERE o.user_id = u.id) AS max_amount
FROM users u;

-- ✅ LEFT JOIN으로 변환 (한 번에 처리)
SELECT
    u.name,
    COALESCE(o.order_count, 0) AS order_count,
    o.max_amount
FROM users u
LEFT JOIN (
    SELECT user_id, COUNT(*) AS order_count, MAX(amount) AS max_amount
    FROM orders
    GROUP BY user_id
) o ON o.user_id = u.id;
```

---

## 6. GROUP BY / ORDER BY 최적화

### GROUP BY 최적화

```sql
-- ❌ filesort + 임시 테이블 사용 (느림)
SELECT status, COUNT(*) FROM orders GROUP BY status;

-- ✅ 인덱스를 활용한 GROUP BY (Loose Index Scan 또는 Tight Index Scan)
CREATE INDEX idx_orders_status ON orders (status);
SELECT status, COUNT(*) FROM orders GROUP BY status;
-- → Using index for group-by
```

### ORDER BY 최적화

```sql
-- filesort 발생 조건:
-- 1. ORDER BY 컬럼에 인덱스가 없음
-- 2. WHERE 조건과 ORDER BY가 다른 인덱스를 사용
-- 3. ORDER BY 컬럼 방향이 인덱스와 불일치

-- ✅ 인덱스로 정렬 (filesort 없음)
-- 인덱스: (user_id, created_at)
SELECT * FROM orders WHERE user_id = 1 ORDER BY created_at DESC;

-- ❌ filesort 발생 (WHERE 범위 조건 + ORDER BY)
SELECT * FROM orders WHERE user_id > 1 ORDER BY created_at DESC;
```

### DISTINCT 최적화

```sql
-- DISTINCT는 내부적으로 GROUP BY와 유사하게 동작

-- ❌ 불필요한 DISTINCT
SELECT DISTINCT u.id, u.name
FROM users u
INNER JOIN orders o ON o.user_id = u.id;
-- → 1:N JOIN이므로 중복 발생, 하지만 GROUP BY가 더 명확

-- ✅ GROUP BY로 대체
SELECT u.id, u.name
FROM users u
INNER JOIN orders o ON o.user_id = u.id
GROUP BY u.id, u.name;

-- ✅ EXISTS로 대체 (중복 자체를 방지)
SELECT u.id, u.name
FROM users u
WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);
```

---

## 7. INSERT / UPDATE / DELETE 최적화

### 대량 INSERT

```sql
-- ❌ 행별 INSERT (매번 트랜잭션 + 인덱스 갱신)
INSERT INTO logs (message) VALUES ('msg1');
INSERT INTO logs (message) VALUES ('msg2');
INSERT INTO logs (message) VALUES ('msg3');

-- ✅ 배치 INSERT (한 번의 트랜잭션으로 처리)
INSERT INTO logs (message) VALUES
    ('msg1'), ('msg2'), ('msg3'), ('msg4'), ('msg5');

-- ✅ 대량 로드 시 LOAD DATA INFILE 사용 (가장 빠름)
LOAD DATA INFILE '/path/to/data.csv'
INTO TABLE logs
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n';
```

### 대량 INSERT 시 추가 팁

```sql
-- 임시로 인덱스 비활성화 (MyISAM만 해당)
ALTER TABLE logs DISABLE KEYS;
-- ... 대량 INSERT ...
ALTER TABLE logs ENABLE KEYS;

-- InnoDB: PK 순서대로 INSERT하면 성능 향상
-- → 클러스터드 인덱스의 페이지 분할(Page Split) 최소화

-- bulk_insert_buffer_size 조정
SET bulk_insert_buffer_size = 256 * 1024 * 1024;  -- 256MB
```

### UPDATE 최적화

```sql
-- ❌ 서브쿼리로 UPDATE (행마다 서브쿼리 실행)
UPDATE orders
SET discount = (SELECT discount_rate FROM promotions WHERE promotions.code = orders.promo_code);

-- ✅ JOIN UPDATE
UPDATE orders o
INNER JOIN promotions p ON p.code = o.promo_code
SET o.discount = p.discount_rate;
```

### DELETE 최적화

```sql
-- ❌ 대량 DELETE (락 오래 유지, 리플리케이션 지연)
DELETE FROM logs WHERE created_at < '2023-01-01';

-- ✅ 배치 DELETE (소량씩 반복)
DELETE FROM logs WHERE created_at < '2023-01-01' LIMIT 10000;
-- → 애플리케이션에서 영향 받은 행이 0이 될 때까지 반복

-- ✅ 파티셔닝 활용 (파티션 단위 즉시 삭제)
ALTER TABLE logs DROP PARTITION p2022;
```

---

## 8. 실전 쿼리 리팩토링

### 사례 1: N+1 쿼리 문제

```sql
-- ❌ N+1 문제 (애플리케이션에서 루프)
-- 1. SELECT * FROM users LIMIT 100;
-- 2. 각 user에 대해: SELECT * FROM orders WHERE user_id = ?  (100번 실행)

-- ✅ JOIN으로 한 번에 조회
SELECT u.*, o.id AS order_id, o.amount
FROM users u
LEFT JOIN orders o ON o.user_id = u.id
LIMIT 100;

-- ✅ 또는 IN 절로 조회
SELECT * FROM orders WHERE user_id IN (1, 2, 3, ..., 100);
```

### 사례 2: 최신 N건 조회

```sql
-- ❌ 느림 (각 사용자마다 서브쿼리)
SELECT *
FROM orders o
WHERE o.id = (
    SELECT id FROM orders WHERE user_id = o.user_id ORDER BY created_at DESC LIMIT 1
);

-- ✅ ROW_NUMBER() 윈도우 함수 (MySQL 8.0+)
SELECT * FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) AS rn
    FROM orders
) ranked
WHERE rn = 1;

-- ✅ LATERAL JOIN (MySQL 8.0.14+)
SELECT u.name, latest.*
FROM users u
CROSS JOIN LATERAL (
    SELECT * FROM orders o
    WHERE o.user_id = u.id
    ORDER BY o.created_at DESC
    LIMIT 1
) latest;
```

### 사례 3: 조건부 집계

```sql
-- ❌ 여러 번 쿼리
SELECT COUNT(*) FROM orders WHERE status = 'pending';
SELECT COUNT(*) FROM orders WHERE status = 'completed';
SELECT COUNT(*) FROM orders WHERE status = 'cancelled';

-- ✅ 조건부 집계로 한 번에 처리
SELECT
    COUNT(CASE WHEN status = 'pending' THEN 1 END) AS pending_count,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed_count,
    COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled_count
FROM orders;

-- ✅ MySQL 8.0+: FILTER 유사 구문
SELECT
    SUM(status = 'pending') AS pending_count,
    SUM(status = 'completed') AS completed_count,
    SUM(status = 'cancelled') AS cancelled_count
FROM orders;
```

---

## 핵심 요약

- MySQL 옵티마이저는 **비용 기반(Cost-Based)**으로 실행 계획을 결정하며, **통계 정보**가 핵심이다
- **슬로우 쿼리 로그**와 **EXPLAIN ANALYZE**로 병목 쿼리를 식별하고 분석한다
- **SELECT \*** 대신 필요한 컬럼만 조회하고, **WHERE 조건의 컬럼에 함수를 적용하지 않는다**
- JOIN 시 **드리븐 테이블의 JOIN 컬럼에 인덱스**가 반드시 필요하며, 불필요한 JOIN은 제거한다
- **상관 서브쿼리**는 JOIN으로 변환하고, **스칼라 서브쿼리**는 LEFT JOIN으로 대체한다
- 대량 INSERT는 **배치 단위**로, 대량 DELETE는 **LIMIT으로 나눠서** 실행한다
- **윈도우 함수**(ROW_NUMBER, RANK 등)로 복잡한 서브쿼리를 간결하게 대체할 수 있다

## 참고 자료

- [MySQL 공식 문서 - Query Optimization](https://dev.mysql.com/doc/refman/8.0/en/select-optimization.html)
- [MySQL 공식 문서 - EXPLAIN Statement](https://dev.mysql.com/doc/refman/8.0/en/explain.html)
- [High Performance MySQL (O'Reilly)](https://www.oreilly.com/library/view/high-performance-mysql/9781492080503/)
