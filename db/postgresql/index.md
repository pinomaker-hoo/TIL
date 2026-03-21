# PostgreSQL

> PostgreSQL은 캘리포니아 대학교 버클리에서 시작된 오픈소스 객체-관계형 데이터베이스 관리 시스템(ORDBMS)으로, 35년 이상의 역사를 가진 가장 진보된 오픈소스 RDBMS이다.

## 목차

1. [PostgreSQL이란 무엇인가?](#1-postgresql이란-무엇인가)
2. [핵심 아키텍처](#2-핵심-아키텍처)
3. [설치 및 초기 설정](#3-설치-및-초기-설정)
4. [데이터 타입](#4-데이터-타입)
5. [테이블 및 스키마 설계](#5-테이블-및-스키마-설계)
6. [인덱스](#6-인덱스)
7. [고급 SQL 기능](#7-고급-sql-기능)
8. [MVCC와 트랜잭션](#8-mvcc와-트랜잭션)
9. [성능 최적화](#9-성능-최적화)
10. [복제와 고가용성](#10-복제와-고가용성)
11. [보안](#11-보안)
12. [PostgreSQL 17 신기능](#12-postgresql-17-신기능)
13. [PostgreSQL 18 신기능](#13-postgresql-18-신기능)
14. [pgvector - 벡터 데이터베이스](#14-pgvector---벡터-데이터베이스)
15. [장점과 단점](#15-장점과-단점)
16. [핵심 요약](#16-핵심-요약)

---

## 1. PostgreSQL이란 무엇인가?

PostgreSQL은 1986년 UC Berkeley의 **POSTGRES 프로젝트**에서 시작되었으며, 현재는 전 세계 개발자 커뮤니티가 개발을 주도하는 **오픈소스 ORDBMS**이다. ACID 트랜잭션, MVCC, 풍부한 데이터 타입, 확장성을 핵심 철학으로 한다.

### 핵심 특징

- **ACID 완전 지원** - 트랜잭션의 원자성, 일관성, 격리성, 지속성을 완벽하게 보장
- **MVCC(Multi-Version Concurrency Control)** - 읽기와 쓰기가 서로를 차단하지 않음
- **풍부한 데이터 타입** - JSON, Array, Range, Geometric, Network 등 다양한 타입 지원
- **확장성(Extensibility)** - 사용자 정의 타입, 함수, 연산자, 인덱스 메서드 생성 가능
- **표준 SQL 준수** - SQL:2023 표준의 대부분을 지원하는 높은 호환성
- **오픈소스** - PostgreSQL License(BSD 계열), 상용 제품에 자유롭게 사용 가능

### 다른 RDBMS와 비교

| 항목 | PostgreSQL | MySQL | Oracle |
|------|-----------|-------|--------|
| 라이선스 | PostgreSQL License (오픈소스) | GPL / 상용 | 상용 |
| MVCC | 네이티브 지원 | InnoDB에서 지원 | 네이티브 지원 |
| JSON 지원 | JSONB (인덱싱 가능) | JSON (인덱싱 제한적) | JSON 지원 |
| 전문 검색 | 내장 tsvector/tsquery | FULLTEXT Index | Oracle Text |
| 확장성 | Extension 시스템 | Plugin 시스템 | Cartridge |
| 파티셔닝 | 선언적 파티셔닝 | 선언적 파티셔닝 | 고급 파티셔닝 |
| 복제 | 스트리밍 + 논리 복제 | 바이너리 로그 복제 | Data Guard |
| 병렬 쿼리 | 지원 | 제한적 | 지원 |

---

## 2. 핵심 아키텍처

### 프로세스 모델

PostgreSQL은 **멀티 프로세스 아키텍처**를 사용한다. 클라이언트 연결마다 별도의 백엔드 프로세스가 생성된다.

```
클라이언트 연결 요청
         ↓
    Postmaster (메인 프로세스)
         ↓
    Backend Process (연결당 1개)
         ↓
    공유 메모리 (Shared Buffers)
         ↓
    디스크 (데이터 파일 / WAL 파일)
```

### 주요 프로세스

| 프로세스 | 역할 |
|---------|------|
| Postmaster | 메인 프로세스, 클라이언트 연결 관리 및 자식 프로세스 생성 |
| Backend | 클라이언트 연결당 1개, SQL 파싱/실행/결과 반환 |
| Background Writer | 더티 페이지를 주기적으로 디스크에 기록 |
| WAL Writer | WAL 버퍼를 WAL 파일에 기록 |
| Checkpointer | 체크포인트 수행, 모든 더티 페이지를 디스크에 기록 |
| Autovacuum Launcher | VACUUM 작업 자동 실행 관리 |
| Stats Collector | 통계 정보 수집 |
| Logical Replication Launcher | 논리 복제 워커 관리 |

### 메모리 구조

```
┌─────────────────────────────────────────┐
│              공유 메모리                    │
│  ┌──────────────────────────────────┐   │
│  │  Shared Buffers (데이터 캐시)      │   │
│  │  - 디스크 페이지의 메모리 캐시        │   │
│  │  - 기본 128MB, 권장: RAM의 25%     │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │  WAL Buffers (로그 버퍼)           │   │
│  │  - WAL 레코드의 메모리 버퍼          │   │
│  │  - 기본 -1 (shared_buffers의 1/32) │   │
│  └──────────────────────────────────┘   │
│  ┌──────────────────────────────────┐   │
│  │  CLOG Buffers (트랜잭션 상태)       │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│         프로세스별 로컬 메모리              │
│  - work_mem: 정렬/해시 작업용 (기본 4MB)   │
│  - maintenance_work_mem: VACUUM 등 (기본 64MB) │
│  - temp_buffers: 임시 테이블용 (기본 8MB)   │
└─────────────────────────────────────────┘
```

### 저장 구조

PostgreSQL은 데이터를 **페이지(8KB 블록)** 단위로 관리한다.

```
데이터 디렉토리 ($PGDATA)
├── base/                  # 데이터베이스별 디렉토리
│   ├── 1/                 # template1
│   ├── 13356/             # postgres
│   └── 16384/             # 사용자 DB
│       ├── 16385          # 테이블 파일 (OID)
│       ├── 16385_fsm      # Free Space Map
│       └── 16385_vm       # Visibility Map
├── global/                # 클러스터 전역 테이블
├── pg_wal/                # WAL 파일
├── pg_xact/               # 트랜잭션 커밋 상태
├── postgresql.conf        # 주요 설정 파일
├── pg_hba.conf            # 클라이언트 인증 설정
└── pg_ident.conf          # 사용자 이름 매핑
```

### WAL(Write-Ahead Logging)

WAL은 PostgreSQL의 데이터 무결성을 보장하는 핵심 메커니즘이다. 데이터 변경 전에 항상 WAL 레코드를 먼저 기록한다.

```
트랜잭션 실행 흐름:
1. BEGIN
2. 변경 내용을 WAL 버퍼에 기록
3. 데이터를 Shared Buffers에서 변경 (더티 페이지)
4. COMMIT → WAL 버퍼를 디스크(WAL 파일)에 fsync
5. 클라이언트에 성공 응답
6. Background Writer가 더티 페이지를 디스크에 기록 (비동기)
```

장애 발생 시 WAL 파일을 재생(Replay)하여 데이터를 복구한다.

---

## 3. 설치 및 초기 설정

### Ubuntu/Debian

```bash
# 공식 저장소 추가
sudo apt install -y postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh

# PostgreSQL 18 설치
sudo apt install -y postgresql-18

# 서비스 시작
sudo systemctl start postgresql
sudo systemctl enable postgresql

# psql 접속
sudo -u postgres psql
```

### macOS (Homebrew)

```bash
brew install postgresql@18

# 서비스 시작
brew services start postgresql@18

# psql 접속
psql postgres
```

### Docker

```bash
docker run -d \
  --name postgres \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=mypassword \
  -e POSTGRES_DB=mydb \
  -v pgdata:/var/lib/postgresql/data \
  postgres:18

# psql 접속
docker exec -it postgres psql -U postgres -d mydb
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  postgres:
    image: postgres:18
    container_name: postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: mydb
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    command:
      - "postgres"
      - "-c"
      - "shared_buffers=256MB"
      - "-c"
      - "work_mem=16MB"

volumes:
  pgdata:
```

### 초기 설정 (postgresql.conf)

```ini
# 메모리 설정
shared_buffers = '1GB'              # RAM의 25% 권장
effective_cache_size = '3GB'        # RAM의 75% 권장
work_mem = '16MB'                   # 연결 수 고려하여 조정
maintenance_work_mem = '256MB'      # VACUUM, CREATE INDEX 시 사용

# WAL 설정
wal_level = 'replica'               # 복제 사용 시 replica 이상
max_wal_size = '2GB'
min_wal_size = '1GB'

# 쿼리 플래너
random_page_cost = 1.1              # SSD 사용 시 1.1~1.5
effective_io_concurrency = 200      # SSD 사용 시 200

# 로깅
log_min_duration_statement = 1000   # 1초 이상 쿼리 로깅
log_statement = 'ddl'               # DDL 문만 로깅

# 연결
max_connections = 200
```

---

## 4. 데이터 타입

### 숫자형

```sql
-- 정수
smallint        -- 2바이트 (-32768 ~ 32767)
integer         -- 4바이트 (-2^31 ~ 2^31-1)
bigint          -- 8바이트 (-2^63 ~ 2^63-1)

-- 자동 증가
smallserial     -- 2바이트 자동 증가 (1 ~ 32767)
serial          -- 4바이트 자동 증가 (1 ~ 2^31-1)
bigserial       -- 8바이트 자동 증가 (1 ~ 2^63-1)

-- 부동소수점
real            -- 4바이트 (6자리 정밀도)
double precision-- 8바이트 (15자리 정밀도)

-- 고정 소수점 (금액 등 정확한 계산에 사용)
numeric(10, 2)  -- 전체 10자리, 소수점 2자리
decimal(10, 2)  -- numeric과 동일
```

### 문자열

```sql
char(n)         -- 고정 길이 문자열 (남는 공간을 공백으로 채움)
varchar(n)      -- 가변 길이 문자열 (최대 n자)
text            -- 무제한 가변 길이 문자열 (PostgreSQL 권장)

-- 실무에서는 대부분 text 또는 varchar를 사용
-- char(n)은 공백 패딩으로 인해 비효율적
```

### 날짜/시간

```sql
date                        -- 날짜 (2024-01-15)
time                        -- 시간 (10:30:00)
time with time zone         -- 타임존 포함 시간
timestamp                   -- 날짜+시간 (2024-01-15 10:30:00)
timestamp with time zone    -- 타임존 포함 (timestamptz, 권장)
interval                    -- 시간 간격 ('1 year 2 months 3 days')

-- 예시
SELECT now();                           -- 현재 시각 (timestamptz)
SELECT now() + interval '7 days';       -- 7일 후
SELECT age(timestamp '2024-01-01');     -- 경과 시간
SELECT date_trunc('month', now());     -- 월 시작 시점
```

### JSON

```sql
json            -- 텍스트로 저장 (입력값 그대로 보존)
jsonb           -- 바이너리로 저장 (파싱 후 저장, 인덱싱 가능, 권장)

-- JSONB 사용 예시
CREATE TABLE products (
    id    serial PRIMARY KEY,
    name  text NOT NULL,
    attrs jsonb DEFAULT '{}'
);

INSERT INTO products (name, attrs) VALUES
    ('노트북', '{"brand": "Apple", "specs": {"ram": 16, "storage": 512}}');

-- JSONB 조회
SELECT attrs->'brand' FROM products;                      -- "Apple" (JSON)
SELECT attrs->>'brand' FROM products;                     -- Apple (텍스트)
SELECT attrs->'specs'->>'ram' FROM products;              -- 16 (텍스트)
SELECT attrs @> '{"brand": "Apple"}' FROM products;       -- true (포함 여부)

-- JSONB 인덱스
CREATE INDEX idx_attrs ON products USING GIN (attrs);
CREATE INDEX idx_brand ON products USING BTREE ((attrs->>'brand'));
```

### 배열

```sql
-- 배열 타입
integer[]           -- 1차원 정수 배열
text[][]            -- 2차원 텍스트 배열

CREATE TABLE posts (
    id   serial PRIMARY KEY,
    title text,
    tags  text[]
);

INSERT INTO posts (title, tags) VALUES
    ('PostgreSQL 입문', ARRAY['database', 'postgresql', 'sql']);

-- 배열 조회
SELECT * FROM posts WHERE 'sql' = ANY(tags);         -- 배열에 포함 여부
SELECT * FROM posts WHERE tags @> ARRAY['database']; -- 배열 포함 연산자
SELECT array_length(tags, 1) FROM posts;             -- 배열 길이
SELECT unnest(tags) FROM posts;                      -- 배열 → 행으로 펼치기
```

### Range 타입

```sql
int4range       -- 정수 범위
int8range       -- bigint 범위
numrange        -- numeric 범위
tsrange         -- timestamp 범위
tstzrange       -- timestamptz 범위
daterange       -- 날짜 범위

-- 예시: 예약 시스템
CREATE TABLE reservations (
    id     serial PRIMARY KEY,
    room   text,
    period tsrange,
    EXCLUDE USING GIST (room WITH =, period WITH &&)  -- 같은 방 시간 중복 방지
);

INSERT INTO reservations (room, period) VALUES
    ('A101', '[2024-03-01 14:00, 2024-03-01 16:00)');

-- 범위 연산
SELECT * FROM reservations WHERE period @> '2024-03-01 15:00'::timestamp;
-- → 해당 시점이 포함된 예약 조회
```

### 기타 타입

```sql
boolean             -- true / false / null
uuid                -- 128비트 UUID
bytea               -- 바이너리 데이터
inet                -- IPv4/IPv6 주소
cidr                -- 네트워크 주소
macaddr             -- MAC 주소
point, line, circle -- 기하학 타입
tsvector            -- 전문 검색용 문서 벡터
tsquery             -- 전문 검색용 쿼리

-- 열거형
CREATE TYPE mood AS ENUM ('happy', 'sad', 'neutral');
CREATE TABLE person (
    name text,
    current_mood mood
);
```

---

## 5. 테이블 및 스키마 설계

### 테이블 생성

```sql
CREATE TABLE users (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email       text NOT NULL UNIQUE,
    name        text NOT NULL,
    password    text NOT NULL,
    role        text NOT NULL DEFAULT 'user' CHECK (role IN ('admin', 'user', 'guest')),
    metadata    jsonb DEFAULT '{}',
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now()
);

-- 코멘트 추가
COMMENT ON TABLE users IS '사용자 테이블';
COMMENT ON COLUMN users.metadata IS '추가 사용자 정보 (JSON)';
```

### 파티셔닝

대규모 테이블을 물리적으로 분할하여 쿼리 성능을 향상시킨다.

```sql
-- Range 파티셔닝 (날짜 기반)
CREATE TABLE events (
    id          bigint GENERATED ALWAYS AS IDENTITY,
    event_time  timestamptz NOT NULL,
    user_id     bigint NOT NULL,
    event_type  text NOT NULL,
    payload     jsonb
) PARTITION BY RANGE (event_time);

-- 파티션 생성
CREATE TABLE events_2024_q1 PARTITION OF events
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
CREATE TABLE events_2024_q2 PARTITION OF events
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
CREATE TABLE events_2024_q3 PARTITION OF events
    FOR VALUES FROM ('2024-07-01') TO ('2024-10-01');
CREATE TABLE events_2024_q4 PARTITION OF events
    FOR VALUES FROM ('2024-10-01') TO ('2025-01-01');

-- 파티션별 인덱스는 부모 테이블에 정의하면 자동 상속
CREATE INDEX idx_events_user_id ON events (user_id);

-- List 파티셔닝 (값 기반)
CREATE TABLE orders (
    id      bigint GENERATED ALWAYS AS IDENTITY,
    region  text NOT NULL,
    amount  numeric(12, 2)
) PARTITION BY LIST (region);

CREATE TABLE orders_kr PARTITION OF orders FOR VALUES IN ('KR');
CREATE TABLE orders_us PARTITION OF orders FOR VALUES IN ('US');
CREATE TABLE orders_jp PARTITION OF orders FOR VALUES IN ('JP');

-- Hash 파티셔닝 (균등 분배)
CREATE TABLE logs (
    id       bigint GENERATED ALWAYS AS IDENTITY,
    user_id  bigint NOT NULL,
    message  text
) PARTITION BY HASH (user_id);

CREATE TABLE logs_p0 PARTITION OF logs FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE logs_p1 PARTITION OF logs FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE logs_p2 PARTITION OF logs FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE logs_p3 PARTITION OF logs FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

---

## 6. 인덱스

PostgreSQL은 다양한 인덱스 타입을 지원한다.

### B-Tree (기본)

```sql
-- 가장 일반적인 인덱스 (등호, 범위 비교)
CREATE INDEX idx_users_email ON users (email);

-- 복합 인덱스
CREATE INDEX idx_events_user_time ON events (user_id, event_time DESC);

-- 부분 인덱스 (조건에 맞는 행만 인덱싱)
CREATE INDEX idx_active_users ON users (email) WHERE role = 'admin';

-- 커버링 인덱스 (INCLUDE)
CREATE INDEX idx_users_email_cover ON users (email) INCLUDE (name, role);
-- → email로 검색 시 테이블 접근 없이 name, role도 반환 가능 (Index Only Scan)
```

### Hash

```sql
-- 등호(=) 비교에만 사용 (범위 비교 불가)
CREATE INDEX idx_users_email_hash ON users USING HASH (email);
-- B-Tree보다 크기가 작고 등호 비교가 약간 빠름
```

### GIN (Generalized Inverted Index)

```sql
-- JSONB, 배열, 전문 검색에 사용
CREATE INDEX idx_products_attrs ON products USING GIN (attrs);
CREATE INDEX idx_posts_tags ON posts USING GIN (tags);

-- 전문 검색 인덱스
CREATE INDEX idx_articles_search ON articles USING GIN (
    to_tsvector('korean', title || ' ' || body)
);

-- trigram 인덱스 (LIKE '%keyword%' 검색 가속)
CREATE EXTENSION pg_trgm;
CREATE INDEX idx_users_name_trgm ON users USING GIN (name gin_trgm_ops);
SELECT * FROM users WHERE name LIKE '%홍길%';  -- 인덱스 사용 가능
```

### GiST (Generalized Search Tree)

```sql
-- 범위 타입, 기하학 타입, 전문 검색에 사용
CREATE INDEX idx_reservations_period ON reservations USING GIST (period);

-- 근접 검색 (PostGIS)
CREATE INDEX idx_locations_geom ON locations USING GIST (geom);
```

### BRIN (Block Range Index)

```sql
-- 물리적으로 정렬된 대용량 테이블에 효과적 (B-Tree보다 훨씬 작은 크기)
CREATE INDEX idx_events_time_brin ON events USING BRIN (event_time);
-- 시계열 데이터처럼 자연스럽게 정렬된 컬럼에 적합
-- 인덱스 크기가 B-Tree의 1/100 수준
```

### 인덱스 관리

```sql
-- 인덱스 사용 통계 확인
SELECT
    schemaname, tablename, indexname,
    idx_scan,      -- 인덱스 스캔 횟수
    idx_tup_read,  -- 인덱스에서 읽은 행 수
    idx_tup_fetch  -- 테이블에서 가져온 행 수
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- 사용되지 않는 인덱스 찾기
SELECT indexname, idx_scan
FROM pg_stat_user_indexes
WHERE idx_scan = 0 AND schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- 온라인 인덱스 생성 (테이블 잠금 없이)
CREATE INDEX CONCURRENTLY idx_users_name ON users (name);

-- 인덱스 재구축
REINDEX INDEX CONCURRENTLY idx_users_name;
```

---

## 7. 고급 SQL 기능

### CTE (Common Table Expression)

```sql
-- 읽기 전용 CTE
WITH monthly_sales AS (
    SELECT
        date_trunc('month', order_date) AS month,
        SUM(amount) AS total
    FROM orders
    GROUP BY 1
)
SELECT month, total,
    total - LAG(total) OVER (ORDER BY month) AS diff
FROM monthly_sales;

-- 재귀 CTE (조직도 트리 탐색)
WITH RECURSIVE org_tree AS (
    -- 시작점: 최상위 노드
    SELECT id, name, manager_id, 1 AS depth
    FROM employees WHERE manager_id IS NULL

    UNION ALL

    -- 재귀: 하위 노드 탐색
    SELECT e.id, e.name, e.manager_id, t.depth + 1
    FROM employees e
    JOIN org_tree t ON e.manager_id = t.id
)
SELECT * FROM org_tree ORDER BY depth, name;
```

### Window Function

```sql
-- 순위 함수
SELECT
    name,
    department,
    salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS rank,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dense_rank,
    PERCENT_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS pct_rank
FROM employees;

-- 누적 합계 / 이동 평균
SELECT
    order_date,
    amount,
    SUM(amount) OVER (ORDER BY order_date) AS running_total,
    AVG(amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d
FROM orders;

-- LAG / LEAD (이전/다음 행 참조)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month,
    revenue - LAG(revenue) OVER (ORDER BY month) AS growth
FROM monthly_stats;
```

### LATERAL JOIN

```sql
-- 각 사용자의 최근 주문 3건 조회
SELECT u.name, recent.*
FROM users u
CROSS JOIN LATERAL (
    SELECT order_date, amount
    FROM orders o
    WHERE o.user_id = u.id
    ORDER BY order_date DESC
    LIMIT 3
) recent;
```

### UPSERT (INSERT ... ON CONFLICT)

```sql
-- 충돌 시 업데이트
INSERT INTO products (sku, name, price, stock)
VALUES ('A001', '키보드', 50000, 100)
ON CONFLICT (sku)
DO UPDATE SET
    price = EXCLUDED.price,
    stock = products.stock + EXCLUDED.stock,
    updated_at = now();

-- 충돌 시 무시
INSERT INTO user_logins (user_id, login_date)
VALUES (1, CURRENT_DATE)
ON CONFLICT DO NOTHING;
```

### MERGE (PostgreSQL 15+)

```sql
MERGE INTO products AS target
USING staging_products AS source
ON target.sku = source.sku
WHEN MATCHED AND source.is_deleted THEN
    DELETE
WHEN MATCHED THEN
    UPDATE SET
        price = source.price,
        stock = source.stock,
        updated_at = now()
WHEN NOT MATCHED THEN
    INSERT (sku, name, price, stock)
    VALUES (source.sku, source.name, source.price, source.stock);
```

### 전문 검색

```sql
-- 전문 검색 설정
ALTER TABLE articles ADD COLUMN search_vector tsvector
    GENERATED ALWAYS AS (
        to_tsvector('english', coalesce(title, '') || ' ' || coalesce(body, ''))
    ) STORED;

CREATE INDEX idx_articles_fts ON articles USING GIN (search_vector);

-- 검색 실행
SELECT title, ts_rank(search_vector, query) AS rank
FROM articles, to_tsquery('english', 'postgresql & performance') AS query
WHERE search_vector @@ query
ORDER BY rank DESC;
```

---

## 8. MVCC와 트랜잭션

### MVCC 동작 원리

PostgreSQL의 MVCC는 각 행에 **xmin(생성 트랜잭션 ID)**과 **xmax(삭제 트랜잭션 ID)**를 기록하여 다중 버전을 관리한다.

```
UPDATE users SET name = 'Bob' WHERE id = 1;

실제 동작:
1. 기존 행의 xmax에 현재 트랜잭션 ID 기록 (삭제 표시)
2. 새로운 행을 INSERT (xmin = 현재 트랜잭션 ID)
3. → 기존 행과 새 행이 동시에 존재 (다른 트랜잭션은 기존 행을 볼 수 있음)

┌──────────────────────────────────────────┐
│ 행 버전 1: xmin=100, xmax=200 (삭제됨)    │
│ 행 버전 2: xmin=200, xmax=∞   (현재)     │
└──────────────────────────────────────────┘
```

### 트랜잭션 격리 수준

```sql
-- Read Committed (기본값)
-- 각 SQL 문이 실행 시점의 스냅샷을 봄
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM accounts;  -- 시점 A의 데이터
-- 다른 트랜잭션이 커밋
SELECT * FROM accounts;  -- 시점 B의 데이터 (변경 반영됨)
COMMIT;

-- Repeatable Read
-- 트랜잭션 시작 시점의 스냅샷을 계속 봄
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT * FROM accounts;  -- 시점 A의 데이터
-- 다른 트랜잭션이 커밋
SELECT * FROM accounts;  -- 여전히 시점 A의 데이터
COMMIT;

-- Serializable
-- 직렬화 가능한 격리 (가장 엄격)
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
-- 동시 트랜잭션 간 충돌 시 serialization failure 발생
COMMIT;
```

### VACUUM

MVCC로 인해 발생하는 **죽은 행(Dead Tuple)**을 정리하는 프로세스이다.

```sql
-- 수동 VACUUM
VACUUM VERBOSE users;           -- 죽은 행 정리 (공간 재사용 가능하게 표시)
VACUUM FULL users;              -- 테이블 재작성 (디스크 공간 반환, 잠금 필요)
VACUUM ANALYZE users;           -- VACUUM + 통계 갱신

-- 테이블의 죽은 행 확인
SELECT
    relname,
    n_live_tup,                 -- 살아있는 행 수
    n_dead_tup,                 -- 죽은 행 수
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC;

-- Autovacuum 설정 (postgresql.conf)
-- autovacuum = on                          -- 기본 활성화
-- autovacuum_vacuum_threshold = 50         -- 최소 50개 죽은 행
-- autovacuum_vacuum_scale_factor = 0.2     -- 테이블의 20%가 죽은 행일 때
-- autovacuum_analyze_threshold = 50
-- autovacuum_analyze_scale_factor = 0.1
```

---

## 9. 성능 최적화

### EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT u.name, COUNT(o.id) AS order_count
FROM users u
JOIN orders o ON o.user_id = u.id
WHERE u.created_at >= '2024-01-01'
GROUP BY u.name
ORDER BY order_count DESC
LIMIT 10;

-- 출력 예시:
-- Limit  (cost=1234.56..1234.78 rows=10 width=40) (actual time=15.2..15.3 rows=10 loops=1)
--   Buffers: shared hit=892 read=45
--   -> Sort  (cost=1234.56..1240.12 rows=2345 width=40) (actual time=15.1..15.2 rows=10 loops=1)
--         Sort Key: (count(o.id)) DESC
--         Sort Method: top-N heapsort  Memory: 26kB
--         -> HashAggregate  ...
--               -> Hash Join  ...
```

핵심 확인 포인트:
- **Seq Scan** vs **Index Scan** - 대규모 테이블에서 Seq Scan이면 인덱스 추가 검토
- **Buffers: shared hit** - 캐시 히트 비율이 높을수록 좋음
- **actual time** - 실제 실행 시간
- **rows** - 예상 행 수와 실제 행 수의 차이가 크면 통계 갱신 필요

### 쿼리 최적화 팁

```sql
-- 1. 적절한 인덱스 활용
-- 나쁜 예: 함수 적용으로 인덱스 미사용
SELECT * FROM users WHERE LOWER(email) = 'alice@example.com';
-- 좋은 예: 표현식 인덱스 생성
CREATE INDEX idx_users_email_lower ON users (LOWER(email));

-- 2. EXISTS vs IN (서브쿼리)
-- 나쁜 예: 대량 데이터에서 IN 서브쿼리
SELECT * FROM users WHERE id IN (SELECT user_id FROM orders);
-- 좋은 예: EXISTS 사용
SELECT * FROM users u WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

-- 3. 페이지네이션 최적화
-- 나쁜 예: OFFSET이 커질수록 느려짐
SELECT * FROM products ORDER BY id LIMIT 20 OFFSET 100000;
-- 좋은 예: 커서 기반 페이지네이션
SELECT * FROM products WHERE id > 100000 ORDER BY id LIMIT 20;

-- 4. 불필요한 SELECT * 지양
-- 나쁜 예
SELECT * FROM users;
-- 좋은 예
SELECT id, name, email FROM users;
```

### Connection Pooling

PostgreSQL은 연결당 프로세스를 생성하므로, 연결 풀링이 매우 중요하다.

```
클라이언트 (수백~수천 연결)
         ↓
    PgBouncer / Pgpool-II (연결 풀러)
         ↓
    PostgreSQL (수십~수백 연결)
```

PgBouncer 설정 예시:

```ini
# pgbouncer.ini
[databases]
mydb = host=localhost port=5432 dbname=mydb

[pgbouncer]
listen_port = 6432
listen_addr = 0.0.0.0
auth_type = scram-sha-256
pool_mode = transaction       # transaction 모드 권장
max_client_conn = 1000
default_pool_size = 25
```

---

## 10. 복제와 고가용성

### 스트리밍 복제 (물리 복제)

Primary 서버의 WAL을 Standby 서버에 전송하여 바이트 단위로 동일한 복제본을 유지한다.

```
┌──────────┐    WAL 스트리밍    ┌──────────┐
│  Primary │  ──────────────→  │ Standby  │
│  (R/W)   │                   │ (Read)   │
└──────────┘                   └──────────┘
```

```sql
-- Primary 서버 설정 (postgresql.conf)
-- wal_level = replica
-- max_wal_senders = 10
-- wal_keep_size = 1GB

-- 복제 슬롯 생성 (WAL 보존 보장)
SELECT pg_create_physical_replication_slot('standby1');

-- Standby 서버 설정 (pg_basebackup으로 초기화)
-- pg_basebackup -h primary_host -D /var/lib/postgresql/data -U replicator -P -R
-- -R 옵션이 standby.signal 파일과 primary_conninfo 자동 생성
```

### 논리 복제

특정 테이블 단위로 데이터를 복제한다. 서로 다른 PostgreSQL 버전 간에도 가능하다.

```sql
-- Publisher (원본 서버)
CREATE PUBLICATION my_pub FOR TABLE users, orders;

-- Subscriber (복제 서버)
CREATE SUBSCRIPTION my_sub
    CONNECTION 'host=primary_host dbname=mydb user=replicator password=secret'
    PUBLICATION my_pub;

-- 특정 행만 복제 (PostgreSQL 15+)
CREATE PUBLICATION pub_kr_orders
    FOR TABLE orders WHERE (region = 'KR');
```

### 고가용성 구성

```
                    ┌────────────┐
                    │   HAProxy  │ ← 클라이언트 연결
                    │  / VIP     │
                    └─────┬──────┘
                          │
              ┌───────────┼───────────┐
              ▼           ▼           ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ Primary  │ │ Standby1 │ │ Standby2 │
        │  (R/W)   │ │  (Read)  │ │  (Read)  │
        └──────────┘ └──────────┘ └──────────┘
              │
         Patroni / repmgr (자동 Failover 관리)
```

---

## 11. 보안

### 인증 설정 (pg_hba.conf)

```
# TYPE  DATABASE  USER       ADDRESS         METHOD
local   all       postgres                   peer
host    all       all        127.0.0.1/32    scram-sha-256
host    all       all        10.0.0.0/8      scram-sha-256
host    all       all        0.0.0.0/0       reject
```

### 역할 및 권한

```sql
-- 역할 생성
CREATE ROLE app_readonly LOGIN PASSWORD 'secure_password';
CREATE ROLE app_readwrite LOGIN PASSWORD 'secure_password';

-- 스키마 및 테이블 권한
GRANT USAGE ON SCHEMA public TO app_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO app_readonly;

GRANT USAGE ON SCHEMA public TO app_readwrite;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_readwrite;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_readwrite;

-- Row Level Security (RLS)
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_orders ON orders
    USING (user_id = current_setting('app.current_user_id')::bigint);
-- → 각 사용자는 자신의 주문만 조회 가능
```

### SSL/TLS 설정

```ini
# postgresql.conf
ssl = on
ssl_cert_file = '/path/to/server.crt'
ssl_key_file = '/path/to/server.key'
ssl_ca_file = '/path/to/ca.crt'
```

---

## 12. PostgreSQL 17 신기능

> PostgreSQL 17은 2024년 9월에 릴리스되었다.

### VACUUM 메모리 관리 개선

새로운 내부 메모리 구조로 VACUUM의 메모리 소비를 **최대 20배 절감**하였다. 대규모 테이블의 VACUUM 속도가 크게 향상되었다.

### WAL 처리 성능 향상

높은 동시성 워크로드에서 WAL 처리 최적화로 **쓰기 처리량이 최대 2배** 향상되었다.

### SQL/JSON 지원 확대

```sql
-- JSON_TABLE: JSON 데이터를 관계형 테이블로 변환
SELECT jt.*
FROM api_responses,
    JSON_TABLE(
        response_body, '$.users[*]'
        COLUMNS (
            id      int     PATH '$.id',
            name    text    PATH '$.name',
            email   text    PATH '$.email',
            active  boolean PATH '$.active'
        )
    ) AS jt;

-- JSON 생성 함수
SELECT JSON('{"key": "value"}');
SELECT JSON_SCALAR(42);
SELECT JSON_SERIALIZE('{"key": "value"}'::jsonb);

-- JSON 쿼리 함수
SELECT JSON_EXISTS('{"a": 1}', '$.a');           -- true
SELECT JSON_VALUE('{"a": 1}', '$.a');            -- 1
SELECT JSON_QUERY('{"a": [1,2]}', '$.a');        -- [1,2]
```

### MERGE RETURNING

```sql
MERGE INTO inventory AS target
USING new_stock AS source ON target.sku = source.sku
WHEN MATCHED THEN UPDATE SET stock = target.stock + source.qty
WHEN NOT MATCHED THEN INSERT (sku, stock) VALUES (source.sku, source.qty)
RETURNING target.*;  -- 변경된 행 반환
```

### 증분 백업

```bash
# 전체 백업
pg_basebackup -D /backup/full -Ft -z -P

# 증분 백업 (변경분만)
pg_basebackup -D /backup/incr1 --incremental=/backup/full/backup_manifest -Ft -z -P

# 증분 백업을 전체 백업으로 복원
pg_combinebackup /backup/full /backup/incr1 -o /backup/restored
```

### COPY ON_ERROR

```sql
-- 오류 발생 시 해당 행만 건너뛰고 계속 진행
COPY users FROM '/data/users.csv' WITH (FORMAT csv, ON_ERROR 'ignore');
```

### 내장 Collation Provider

```sql
-- 플랫폼 독립적인 정렬 순서 보장
CREATE DATABASE mydb
    LOCALE_PROVIDER = builtin
    BUILTIN_LOCALE = 'C.UTF-8';
```

---

## 13. PostgreSQL 18 신기능

> PostgreSQL 18은 2025년 9월에 릴리스되었다.

### 비동기 I/O (AIO) 서브시스템

PostgreSQL 18의 가장 핵심적인 변화이다. 스토리지 읽기 성능이 **최대 3배** 향상되었다.

```ini
# postgresql.conf
# io_method = 'worker'     # 워커 기반 AIO (기본값)
# io_method = 'io_uring'   # Linux io_uring (Linux 전용, 고성능)
# io_method = 'sync'       # 기존 동기 방식
```

AIO가 적용되는 연산:
- Sequential Scan (순차 스캔)
- Bitmap Heap Scan
- VACUUM
- 기타 대량 읽기 작업

### Skip Scan

다중 컬럼 B-Tree 인덱스에서 선행 컬럼 조건 없이도 인덱스를 활용할 수 있다.

```sql
-- 인덱스: (country, city)
CREATE INDEX idx_location ON users (country, city);

-- PostgreSQL 17 이전: country 조건 없으면 Seq Scan
-- PostgreSQL 18: Skip Scan으로 인덱스 활용 가능
SELECT * FROM users WHERE city = 'Seoul';
-- → country 값을 건너뛰면서 city = 'Seoul'인 행만 인덱스에서 검색
```

### UUIDv7

시간 순서가 보장되는 UUID를 생성한다. 인덱싱과 캐싱 성능이 크게 향상된다.

```sql
-- UUIDv4 (기존): 완전 랜덤 → 인덱스 삽입 시 랜덤 I/O
SELECT gen_random_uuid();
-- f47ac10b-58cc-4372-a567-0e02b2c3d479

-- UUIDv7 (신규): 타임스탬프 기반 → 순차적 인덱스 삽입
SELECT uuidv7();
-- 019462a0-b1c0-7def-8a3b-1234567890ab
-- ^^^^^^^^ 타임스탬프 부분

-- UUIDv4의 별칭
SELECT uuidv4();  -- gen_random_uuid()와 동일

-- PK로 UUIDv7 사용 (권장)
CREATE TABLE orders (
    id    uuid PRIMARY KEY DEFAULT uuidv7(),
    total numeric(12, 2)
);
```

### Virtual Generated Column

쿼리 시점에 계산되는 가상 컬럼이다. 디스크 공간을 사용하지 않는다.

```sql
CREATE TABLE products (
    price     numeric(10, 2),
    tax_rate  numeric(4, 2),
    -- 가상 컬럼: 디스크 저장 없이 조회 시 계산
    total     numeric(10, 2) GENERATED ALWAYS AS (price * (1 + tax_rate)) VIRTUAL,
    -- 저장 컬럼: 디스크에 저장 (기존 방식)
    label     text GENERATED ALWAYS AS (price::text || '원') STORED
);
```

### RETURNING에서 OLD/NEW 참조

```sql
-- UPDATE 전후 값을 동시에 확인
UPDATE products SET price = price * 1.1
WHERE category = 'electronics'
RETURNING
    OLD.price AS old_price,
    NEW.price AS new_price,
    NEW.price - OLD.price AS diff;

-- DELETE 시 삭제된 행 정보 확인
DELETE FROM expired_sessions
WHERE expires_at < now()
RETURNING OLD.*;
```

### Temporal Constraint (시간 제약 조건)

시간 범위의 중복을 방지하는 제약 조건이다.

```sql
CREATE TABLE room_bookings (
    id          bigint GENERATED ALWAYS AS IDENTITY,
    room_id     integer NOT NULL,
    booked_at   tstzrange NOT NULL,
    -- 같은 방에 대해 시간 범위가 겹치지 않도록 제약
    PRIMARY KEY (room_id, booked_at WITHOUT OVERLAPS)
);

-- 겹치는 예약 시도 시 오류 발생
INSERT INTO room_bookings (room_id, booked_at)
VALUES (1, '[2024-03-01 14:00, 2024-03-01 16:00)');
INSERT INTO room_bookings (room_id, booked_at)
VALUES (1, '[2024-03-01 15:00, 2024-03-01 17:00)');
-- ERROR: conflicting key value violates exclusion constraint
```

### OAuth 2.0 인증

```ini
# pg_hba.conf
host all all 0.0.0.0/0 oauth
```

PostgreSQL 확장 모듈을 통해 OAuth 2.0 기반 인증을 지원한다. 기존 MD5 인증은 **deprecated** 처리되었으며, SCRAM-SHA-256 사용이 권장된다.

### 병렬 GIN 인덱스 빌드

대규모 테이블의 GIN 인덱스 생성이 병렬로 처리되어 속도가 크게 향상되었다.

```sql
-- 병렬 GIN 인덱스 생성 (자동으로 병렬 처리)
SET max_parallel_maintenance_workers = 4;
CREATE INDEX idx_docs_search ON documents USING GIN (search_vector);
```

### EXPLAIN ANALYZE 개선

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE user_id = 123;
-- PostgreSQL 18: 버퍼 접근 횟수, 인덱스 룩업 횟수가 기본으로 표시됨
-- VERBOSE 추가 시 CPU, WAL, 평균 읽기 통계도 표시
```

### 업그레이드 성능 향상

- **플래너 통계 유지**: 메이저 버전 업그레이드 후에도 기존 통계가 보존되어 성능 저하 없이 즉시 정상 운영 가능
- **pg_upgrade --swap**: 디렉토리 복사 대신 스왑으로 업그레이드 시간 단축
- **pg_upgrade --jobs**: 병렬 처리로 대규모 데이터베이스 업그레이드 가속

### PG_UNICODE_FAST Collation

```sql
-- 유니코드 의미론을 지원하면서도 빠른 비교 성능
CREATE TABLE users (
    name text COLLATE "PG_UNICODE_FAST"
);

-- casefold() 함수: 대소문자 무시 비교
SELECT casefold('PostgreSQL');  -- 'postgresql'
```

### Wire Protocol v3.2

PostgreSQL 7.4(2003년) 이후 최초의 프로토콜 버전 업데이트이다. 클라이언트 라이브러리의 점진적 지원이 예정되어 있다.

---

## 14. pgvector - 벡터 데이터베이스

> pgvector는 PostgreSQL을 벡터 데이터베이스로 확장하는 오픈소스 Extension이다. AI/ML 임베딩을 저장하고 유사도 검색을 수행할 수 있어, 별도의 벡터 DB(Pinecone, Qdrant 등) 없이 PostgreSQL 하나로 RAG, 시맨틱 검색 등을 구현할 수 있다.

### 왜 PostgreSQL + pgvector인가?

2024~2025년까지는 Pinecone, Weaviate, Qdrant 같은 **전용 벡터 데이터베이스**가 주목받았지만, 2026년 현재는 벡터가 "데이터베이스 카테고리"가 아닌 **"데이터 타입"**으로 자리잡는 추세이다.

```
기존 방식:
┌──────────┐     ┌──────────────┐     ┌──────────┐
│  App     │ ──→ │  PostgreSQL  │     │ Pinecone │
│          │ ──→ │  (관계형 데이터) │     │ (벡터)    │
└──────────┘     └──────────────┘     └──────────┘
    ↑ 데이터 동기화 문제, 인프라 복잡도 증가

pgvector 방식:
┌──────────┐     ┌──────────────────────────┐
│  App     │ ──→ │  PostgreSQL + pgvector   │
│          │     │  (관계형 + 벡터 통합)       │
└──────────┘     └──────────────────────────┘
    ↑ 단일 DB, ACID 트랜잭션, JOIN 가능
```

### 설치

```bash
# Ubuntu/Debian
sudo apt install postgresql-18-pgvector

# macOS
brew install pgvector

# Docker (공식 이미지에 포함)
docker run -d --name pgvector postgres:18

# 또는 소스 빌드
cd /tmp && git clone https://github.com/pgvector/pgvector.git
cd pgvector && make && sudo make install
```

```sql
-- Extension 활성화
CREATE EXTENSION vector;
```

### 벡터 데이터 타입

pgvector는 4가지 벡터 타입을 지원한다.

| 타입 | 설명 | 최대 차원 |
|------|------|----------|
| `vector` | 단정밀도 부동소수점 (float32) | 2,000 |
| `halfvec` | 반정밀도 부동소수점 (float16) | 4,000 |
| `bit` | 바이너리 벡터 | 64,000 |
| `sparsevec` | 희소 벡터 | 1,000 (비영 원소) |

```sql
-- 테이블 생성
CREATE TABLE documents (
    id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title    text NOT NULL,
    content  text NOT NULL,
    embedding vector(1536)    -- OpenAI text-embedding-3-small 차원
);

-- 벡터 삽입
INSERT INTO documents (title, content, embedding) VALUES
    ('PostgreSQL 입문', '...', '[0.1, 0.2, ..., 0.05]'),
    ('벡터 검색 가이드', '...', '[0.3, 0.1, ..., 0.08]');
```

### 거리 함수 (유사도 검색)

| 연산자 | 거리 메트릭 | 용도 |
|--------|-----------|------|
| `<->` | L2 (유클리드) 거리 | 일반적인 유사도 검색 |
| `<=>` | 코사인 거리 | 텍스트 임베딩 (방향 유사도) |
| `<#>` | 내적 (음수) | 정규화된 벡터의 유사도 |
| `<+>` | L1 (맨해튼) 거리 | 특수 용도 |
| `<~>` | 해밍 거리 | 바이너리 벡터 |
| `<%>` | 자카드 거리 | 바이너리 벡터 |

```sql
-- 코사인 유사도로 가장 가까운 5개 문서 검색
SELECT id, title, embedding <=> '[0.1, 0.2, ..., 0.05]' AS distance
FROM documents
ORDER BY embedding <=> '[0.1, 0.2, ..., 0.05]'
LIMIT 5;

-- L2 거리 기반 검색
SELECT id, title
FROM documents
ORDER BY embedding <-> '[0.1, 0.2, ..., 0.05]'
LIMIT 5;

-- 유사도 임계값 필터링
SELECT id, title
FROM documents
WHERE embedding <=> '[0.1, 0.2, ..., 0.05]' < 0.3
ORDER BY embedding <=> '[0.1, 0.2, ..., 0.05]';
```

### 인덱스

인덱스 없이도 정확한 최근접 이웃(Exact KNN) 검색이 가능하지만, 대규모 데이터에서는 근사 최근접 이웃(ANN) 인덱스가 필수적이다.

#### HNSW (권장)

```sql
-- HNSW 인덱스: 높은 검색 품질, 빠른 쿼리
CREATE INDEX idx_docs_embedding ON documents
    USING hnsw (embedding vector_cosine_ops);

-- 파라미터 튜닝
CREATE INDEX idx_docs_embedding ON documents
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);
-- m: 그래프의 최대 연결 수 (높을수록 정확, 메모리 증가)
-- ef_construction: 인덱스 빌드 시 탐색 범위 (높을수록 정확, 빌드 느림)

-- 쿼리 시 검색 범위 조정
SET hnsw.ef_search = 100;  -- 기본 40, 높을수록 정확하지만 느림
```

#### IVFFlat

```sql
-- IVFFlat 인덱스: 빠른 빌드, 낮은 메모리 (데이터가 먼저 있어야 함)
CREATE INDEX idx_docs_embedding_ivf ON documents
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
-- lists: 클러스터 수 (행 수의 sqrt 권장)

-- 쿼리 시 탐색할 클러스터 수
SET ivfflat.probes = 10;  -- 기본 1, 높을수록 정확
```

#### 거리 함수별 Ops 클래스

| 거리 함수 | vector | halfvec | bit |
|-----------|--------|---------|-----|
| L2 | `vector_l2_ops` | `halfvec_l2_ops` | - |
| 코사인 | `vector_cosine_ops` | `halfvec_cosine_ops` | - |
| 내적 | `vector_ip_ops` | `halfvec_ip_ops` | - |
| 해밍 | - | - | `bit_hamming_ops` |

### 실전 예제: RAG 시스템

PostgreSQL + pgvector로 RAG(Retrieval-Augmented Generation) 파이프라인을 구축하는 예시이다.

```sql
-- 1. 문서 테이블 생성
CREATE TABLE knowledge_base (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title      text NOT NULL,
    content    text NOT NULL,
    chunk_idx  integer NOT NULL,           -- 문서 분할 인덱스
    metadata   jsonb DEFAULT '{}',
    embedding  vector(1536),               -- 임베딩 벡터
    created_at timestamptz DEFAULT now()
);

-- 2. HNSW 인덱스 생성
CREATE INDEX idx_kb_embedding ON knowledge_base
    USING hnsw (embedding vector_cosine_ops);

-- 3. 메타데이터 인덱스 (하이브리드 검색용)
CREATE INDEX idx_kb_metadata ON knowledge_base USING GIN (metadata);

-- 4. 시맨틱 검색 + 메타데이터 필터링
SELECT id, title, content,
    1 - (embedding <=> $1::vector) AS similarity  -- 코사인 유사도
FROM knowledge_base
WHERE metadata @> '{"category": "database"}'       -- 메타데이터 필터
ORDER BY embedding <=> $1::vector
LIMIT 5;
```

### 실전 예제: Node.js/TypeScript

```typescript
import { Pool } from 'pg';
import OpenAI from 'openai';

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const openai = new OpenAI();

// 임베딩 생성
async function getEmbedding(text: string): Promise<number[]> {
    const response = await openai.embeddings.create({
        model: 'text-embedding-3-small',
        input: text,
    });
    return response.data[0].embedding;
}

// 문서 저장
async function insertDocument(title: string, content: string) {
    const embedding = await getEmbedding(content);
    await pool.query(
        `INSERT INTO knowledge_base (title, content, chunk_idx, embedding)
         VALUES ($1, $2, 0, $3::vector)`,
        [title, content, JSON.stringify(embedding)]
    );
}

// 유사 문서 검색
async function searchSimilar(query: string, limit = 5) {
    const queryEmbedding = await getEmbedding(query);
    const result = await pool.query(
        `SELECT id, title, content,
            1 - (embedding <=> $1::vector) AS similarity
         FROM knowledge_base
         ORDER BY embedding <=> $1::vector
         LIMIT $2`,
        [JSON.stringify(queryEmbedding), limit]
    );
    return result.rows;
}

// RAG: 검색 → LLM 응답 생성
async function ragQuery(question: string) {
    const docs = await searchSimilar(question, 3);
    const context = docs.map(d => d.content).join('\n\n');

    const response = await openai.chat.completions.create({
        model: 'gpt-4o',
        messages: [
            { role: 'system', content: `다음 문서를 참고하여 답변하세요:\n\n${context}` },
            { role: 'user', content: question },
        ],
    });
    return response.choices[0].message.content;
}
```

### pgvector 생태계

pgvector를 보완하는 확장 도구들이 있다.

| 확장 | 설명 |
|------|------|
| **pgvectorscale** | Timescale에서 개발한 고성능 벡터 인덱스(StreamingDiskANN). Pinecone 대비 **28배 낮은 p95 레이턴시**, **16배 높은 처리량** |
| **pgai** | SQL에서 직접 LLM API(OpenAI, Anthropic, Cohere, Ollama) 호출. 임베딩 생성과 저장을 단일 쿼리로 처리 |
| **pgai Vectorizer** | 테이블 데이터 변경 시 자동으로 임베딩을 생성/갱신 |

```sql
-- pgai 사용 예시: SQL에서 직접 임베딩 생성
SELECT ai.openai_embed(
    'text-embedding-3-small',
    'PostgreSQL은 훌륭한 데이터베이스입니다'
);

-- 임베딩 생성 + 즉시 저장 (단일 쿼리)
INSERT INTO knowledge_base (title, content, embedding)
SELECT
    'PostgreSQL 소개',
    '...',
    ai.openai_embed('text-embedding-3-small', '...');
```

### 전용 벡터 DB vs pgvector 비교

| 항목 | 전용 벡터 DB (Pinecone 등) | PostgreSQL + pgvector |
|------|--------------------------|----------------------|
| 설정 난이도 | 쉬움 (매니지드) | 보통 (Extension 설치) |
| ACID 트랜잭션 | 미지원 | 완전 지원 |
| 관계형 데이터 JOIN | 불가능 | 가능 |
| 하이브리드 검색 | 제한적 | JSONB + GIN + 벡터 결합 |
| 인프라 비용 | 별도 서비스 비용 | 기존 PostgreSQL 활용 |
| 대규모 벡터 성능 | 최적화됨 | pgvectorscale로 대등 |
| 생태계 | 독자적 | PostgreSQL 전체 생태계 |

---

## 15. 장점과 단점

### 장점

- **ACID 완전 지원** - 데이터 무결성과 트랜잭션 안정성 보장
- **풍부한 데이터 타입** - JSON, Array, Range, Geometric 등 다양한 네이티브 타입
- **확장성** - Extension 시스템으로 PostGIS, TimescaleDB, pgvector 등 생태계 확장
- **표준 SQL 준수도** - 상용 DB 수준의 SQL 표준 지원
- **강력한 인덱싱** - B-Tree, GIN, GiST, BRIN, Hash 등 다양한 인덱스 전략
- **논리 복제** - 테이블 단위 복제, 이종 버전 간 복제 가능
- **오픈소스** - 라이선스 비용 없음, 활발한 커뮤니티

### 단점

- **연결 비용** - 연결당 프로세스 생성으로 대규모 연결 시 PgBouncer 등 필요
- **VACUUM 오버헤드** - MVCC 특성상 주기적인 VACUUM이 필수적
- **쓰기 증폭** - UPDATE 시 새 행을 INSERT하는 MVCC 구조로 쓰기 증폭 발생
- **수평 확장 제한** - 네이티브 샤딩 미지원 (Citus 등 확장 필요)
- **학습 곡선** - 풍부한 기능만큼 깊이 이해하기 위한 학습 필요

---

## 16. 핵심 요약

- PostgreSQL은 **ACID 완전 지원**의 오픈소스 ORDBMS로, 가장 진보된 관계형 데이터베이스이다
- **MVCC**를 통해 읽기와 쓰기가 서로를 차단하지 않으며, 높은 동시성을 제공한다
- **JSONB, Array, Range** 등 풍부한 데이터 타입과 **GIN, GiST, BRIN** 등 다양한 인덱스를 지원한다
- **Extension 시스템**으로 PostGIS, TimescaleDB, pgvector 등 생태계를 확장할 수 있다
- PostgreSQL 17에서는 **VACUUM 메모리 20배 절감**, **SQL/JSON JSON_TABLE**, **증분 백업** 등이 추가되었다
- PostgreSQL 18에서는 **비동기 I/O(최대 3배 성능 향상)**, **UUIDv7**, **Skip Scan**, **Virtual Generated Column**, **Temporal Constraint**, **OAuth 2.0** 등 대규모 개선이 이루어졌다
- **pgvector** Extension으로 PostgreSQL을 벡터 데이터베이스로 확장하여, 별도 벡터 DB 없이 AI/ML 임베딩 저장과 유사도 검색이 가능하다
- 연결 풀링(PgBouncer)과 VACUUM 관리가 운영의 핵심 포인트이다

## 참고 자료

- [PostgreSQL 공식 문서](https://www.postgresql.org/docs/)
- [PostgreSQL 17 릴리스 노트](https://www.postgresql.org/about/news/postgresql-17-released-2936/)
- [PostgreSQL 18 릴리스 노트](https://www.postgresql.org/about/news/postgresql-18-released-3142/)
- [PostgreSQL Wiki](https://wiki.postgresql.org/)
- [PostgreSQL GitHub Mirror](https://github.com/postgres/postgres)
- [pgvector GitHub](https://github.com/pgvector/pgvector)
- [pgvectorscale GitHub](https://github.com/timescale/pgvectorscale)
- [pgai GitHub](https://github.com/timescale/pgai)
