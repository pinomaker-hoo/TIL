# ClickHouse

> ClickHouse는 Yandex에서 개발한 오픈소스 컬럼 지향(Column-Oriented) OLAP 데이터베이스로, 대규모 데이터에 대한 실시간 분석 쿼리를 초고속으로 처리한다.

## 목차

1. [ClickHouse란 무엇인가?](#1-clickhouse란-무엇인가)
2. [컬럼 지향 vs 행 지향 저장 방식](#2-컬럼-지향-vs-행-지향-저장-방식)
3. [핵심 아키텍처](#3-핵심-아키텍처)
4. [설치 및 초기 설정](#4-설치-및-초기-설정)
5. [데이터 타입](#5-데이터-타입)
6. [테이블 엔진(Table Engine)](#6-테이블-엔진table-engine)
7. [MergeTree 엔진 상세](#7-mergetree-엔진-상세)
8. [SQL 쿼리 기본](#8-sql-쿼리-기본)
9. [고급 기능](#9-고급-기능)
10. [분산 아키텍처](#10-분산-아키텍처)
11. [성능 최적화](#11-성능-최적화)
12. [장점과 단점](#12-장점과-단점)
13. [실전 활용 사례](#13-실전-활용-사례)
14. [핵심 요약](#14-핵심-요약)

---

## 1. ClickHouse란 무엇인가?

ClickHouse는 **Yandex**에서 웹 분석 서비스(Yandex.Metrica)를 위해 개발한 컬럼 지향 OLAP(Online Analytical Processing) 데이터베이스 관리 시스템이다. 2016년에 오픈소스로 공개되었으며, 현재는 **ClickHouse, Inc.**에서 개발을 주도하고 있다.

ClickHouse의 핵심 특징은 다음과 같다:

- **컬럼 지향 저장** - 분석 쿼리에 최적화된 저장 방식
- **실시간 쿼리 처리** - 수십억 행에 대한 쿼리를 밀리초~초 단위로 처리
- **높은 압축률** - 컬럼 단위 압축으로 디스크 사용량 절감
- **벡터화 쿼리 실행** - SIMD 명령어를 활용한 CPU 최적화
- **SQL 호환** - 표준 SQL을 지원하여 학습 비용이 낮음

### OLTP vs OLAP

| 항목 | OLTP (MySQL, PostgreSQL) | OLAP (ClickHouse) |
|------|--------------------------|---------------------|
| 목적 | 트랜잭션 처리 | 분석 쿼리 처리 |
| 쿼리 패턴 | 소수의 행을 빈번하게 읽기/쓰기 | 대량의 행을 집계/분석 |
| 저장 방식 | 행 지향(Row-Oriented) | 컬럼 지향(Column-Oriented) |
| 예시 쿼리 | `SELECT * FROM users WHERE id = 1` | `SELECT country, COUNT(*) FROM logs GROUP BY country` |
| 업데이트 | 빈번한 UPDATE/DELETE | INSERT 위주, UPDATE/DELETE 제한적 |

---

## 2. 컬럼 지향 vs 행 지향 저장 방식

### 행 지향 저장 (Row-Oriented)

MySQL, PostgreSQL 같은 전통적인 RDBMS의 방식이다. 한 행의 모든 컬럼 데이터가 연속으로 저장된다.

```
저장 순서:
| id=1, name="Alice", age=30, country="KR" |
| id=2, name="Bob",   age=25, country="US" |
| id=3, name="Carol", age=28, country="KR" |
```

**장점**: 특정 행의 전체 데이터를 빠르게 가져올 수 있음 (`SELECT * FROM users WHERE id = 1`)

### 컬럼 지향 저장 (Column-Oriented)

ClickHouse의 방식이다. 같은 컬럼의 데이터가 연속으로 저장된다.

```
저장 순서:
id:      | 1 | 2 | 3 |
name:    | "Alice" | "Bob" | "Carol" |
age:     | 30 | 25 | 28 |
country: | "KR" | "US" | "KR" |
```

**장점**:

1. **필요한 컬럼만 읽기** - `SELECT country, COUNT(*) FROM users GROUP BY country` 실행 시 `country` 컬럼만 디스크에서 읽으면 됨
2. **높은 압축률** - 같은 타입의 데이터가 연속 저장되므로 압축 효율이 높음
3. **벡터화 처리** - CPU의 SIMD 명령어로 컬럼 데이터를 한꺼번에 처리 가능

### 성능 비교 예시

1억 행, 100개 컬럼의 테이블에서 3개 컬럼만 조회하는 경우:

```
행 지향: 100개 컬럼 전부 읽기 → 디스크 I/O 100%
컬럼 지향: 3개 컬럼만 읽기   → 디스크 I/O 3%
```

---

## 3. 핵심 아키텍처

### 전체 구조

```
클라이언트 (HTTP / TCP / JDBC / ODBC)
          ↓
     쿼리 파서 / 분석기
          ↓
     쿼리 플래너 / 최적화기
          ↓
     쿼리 실행 엔진 (벡터화 처리)
          ↓
     테이블 엔진 레이어
          ↓
     스토리지 레이어 (컬럼 단위 파일)
```

### 데이터 저장 구조

ClickHouse는 데이터를 **파트(Part)** 단위로 저장한다.

```
테이블 디렉토리/
├── 202401_1_1_0/          # 파트 (partition_minBlock_maxBlock_level)
│   ├── primary.idx        # 프라이머리 인덱스 (희소 인덱스)
│   ├── id.bin             # id 컬럼 데이터 (압축)
│   ├── id.mrk2            # id 컬럼 마크 파일 (인덱스 → 데이터 매핑)
│   ├── name.bin           # name 컬럼 데이터
│   ├── name.mrk2          # name 컬럼 마크 파일
│   ├── count.txt          # 행 수
│   └── columns.txt        # 컬럼 정보
├── 202401_2_2_0/          # 또 다른 파트
└── 202402_3_3_0/          # 다른 파티션의 파트
```

### 벡터화 쿼리 실행

ClickHouse는 한 행씩 처리하는 것이 아니라, 컬럼의 값들을 **벡터(배열)** 단위로 한꺼번에 처리한다.

```
전통적 방식 (행 단위):
for each row:
    result += row.amount

ClickHouse 방식 (벡터 단위):
for each block of 8192 values:
    result += SIMD_SUM(block)    # CPU SIMD 명령어로 한번에 합산
```

---

## 4. 설치 및 초기 설정

### Ubuntu/Debian

```bash
# 공식 저장소 추가
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL 'https://packages.clickhouse.com/rpm/lts/repodata/repomd.xml.key' | sudo gpg --dearmor -o /usr/share/keyrings/clickhouse-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list

sudo apt-get update

# ClickHouse 설치
sudo apt-get install -y clickhouse-server clickhouse-client

# 서버 시작
sudo systemctl start clickhouse-server

# 클라이언트 접속
clickhouse-client
```

### Docker

```bash
# 단일 노드 실행
docker run -d \
  --name clickhouse-server \
  -p 8123:8123 \
  -p 9000:9000 \
  -v clickhouse-data:/var/lib/clickhouse \
  -v clickhouse-logs:/var/log/clickhouse-server \
  clickhouse/clickhouse-server

# 클라이언트 접속
docker exec -it clickhouse-server clickhouse-client
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: clickhouse
    ports:
      - "8123:8123"   # HTTP 인터페이스
      - "9000:9000"   # Native TCP 인터페이스
    volumes:
      - clickhouse-data:/var/lib/clickhouse
      - clickhouse-logs:/var/log/clickhouse-server
      - ./config.xml:/etc/clickhouse-server/config.d/custom.xml
    ulimits:
      nofile:
        soft: 262144
        hard: 262144

volumes:
  clickhouse-data:
  clickhouse-logs:
```

### macOS (Homebrew)

```bash
brew install clickhouse

# 서버 시작
clickhouse server

# 클라이언트 접속 (다른 터미널에서)
clickhouse client
```

---

## 5. 데이터 타입

### 숫자형

```sql
-- 정수
Int8, Int16, Int32, Int64, Int128, Int256
UInt8, UInt16, UInt32, UInt64, UInt128, UInt256

-- 부동소수점
Float32, Float64

-- Decimal (고정 소수점, 금액 등에 사용)
Decimal32(S), Decimal64(S), Decimal128(S)
-- S = 소수점 이하 자릿수

-- 예시
CREATE TABLE numbers (
    tiny      UInt8,           -- 0 ~ 255
    normal    Int32,           -- -2^31 ~ 2^31 - 1
    big       UInt64,          -- 0 ~ 2^64 - 1
    price     Decimal64(2),    -- 소수점 2자리 (99999999.99)
    ratio     Float64
) ENGINE = MergeTree()
ORDER BY tiny;
```

### 문자열

```sql
String              -- 가변 길이 문자열 (제한 없음)
FixedString(N)      -- 고정 길이 N바이트 문자열
UUID                -- 128비트 UUID

-- Enum (열거형)
Enum8('active' = 1, 'inactive' = 2)
Enum16('pending' = 0, 'approved' = 1, 'rejected' = 2)
```

### 날짜/시간

```sql
Date                -- 날짜 (2024-01-15)
Date32              -- 확장 범위 날짜
DateTime            -- 날짜+시간 (2024-01-15 10:30:00)
DateTime64(3)       -- 밀리초 정밀도 (2024-01-15 10:30:00.123)
DateTime64(6)       -- 마이크로초 정밀도

-- 타임존 지정
DateTime('Asia/Seoul')
DateTime64(3, 'UTC')
```

### 복합 타입

```sql
-- 배열
Array(UInt32)                    -- [1, 2, 3]
Array(String)                    -- ['a', 'b', 'c']

-- 튜플
Tuple(String, UInt32)            -- ('hello', 42)

-- Map
Map(String, UInt64)              -- {'key1': 1, 'key2': 2}

-- Nullable (NULL 허용)
Nullable(String)                 -- 'value' 또는 NULL
-- 주의: Nullable은 성능 오버헤드가 있으므로 꼭 필요한 경우에만 사용

-- LowCardinality (카디널리티가 낮은 컬럼 최적화)
LowCardinality(String)           -- 국가코드, 상태값 등에 적합
```

---

## 6. 테이블 엔진(Table Engine)

ClickHouse에서 테이블 엔진은 데이터의 **저장 방식, 읽기/쓰기 동작, 인덱싱, 복제** 등을 결정하는 핵심 개념이다.

### MergeTree 계열 (프로덕션 주력)

| 엔진 | 설명 |
|------|------|
| `MergeTree` | 가장 기본적이고 강력한 엔진. 대부분의 사용 사례에 적합 |
| `ReplacingMergeTree` | 같은 정렬 키를 가진 행 중 최신 행만 유지 (중복 제거) |
| `SummingMergeTree` | 같은 정렬 키를 가진 행의 수치 컬럼을 자동 합산 |
| `AggregatingMergeTree` | 사전 집계(Pre-Aggregation)를 수행 |
| `CollapsingMergeTree` | Sign 컬럼으로 행의 삭제/업데이트를 표현 |
| `VersionedCollapsingMergeTree` | 버전 기반으로 행의 상태 변경을 관리 |

### 그 외 엔진

| 엔진 | 설명 |
|------|------|
| `Log`, `TinyLog` | 소규모 데이터용, 간단한 로그 저장 |
| `Memory` | 메모리에만 저장 (서버 재시작 시 소멸) |
| `Buffer` | 메모리 버퍼로 데이터를 모은 뒤 대상 테이블에 Flush |
| `Distributed` | 분산 테이블, 여러 샤드에 쿼리를 분산 |
| `MaterializedView` | 물리화된 뷰, 데이터 삽입 시 자동으로 집계 |
| `Kafka`, `RabbitMQ` | 메시지 큐와 연동하여 데이터 수집 |
| `S3` | Amazon S3에 저장된 데이터를 직접 쿼리 |

---

## 7. MergeTree 엔진 상세

MergeTree는 ClickHouse의 가장 중요한 테이블 엔진이다.

### 기본 구조

```sql
CREATE TABLE events (
    event_date   Date,
    event_time   DateTime,
    user_id      UInt64,
    event_type   LowCardinality(String),
    page_url     String,
    duration_ms  UInt32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(event_date)    -- 월 단위 파티셔닝
ORDER BY (user_id, event_time)       -- 정렬 키 (= 프라이머리 키)
TTL event_date + INTERVAL 90 DAY     -- 90일 후 자동 삭제
SETTINGS index_granularity = 8192;   -- 인덱스 세분화 단위
```

### 프라이머리 인덱스 (희소 인덱스)

ClickHouse의 프라이머리 인덱스는 B-Tree가 아닌 **희소 인덱스(Sparse Index)**이다. 모든 행이 아니라 매 `index_granularity`(기본 8192)행마다 하나의 인덱스 엔트리를 저장한다.

```
데이터 (ORDER BY user_id):
┌──────────────────────────────────┐
│ Granule 0: user_id 1~8192       │ ← 인덱스: user_id=1
│ Granule 1: user_id 8193~16384   │ ← 인덱스: user_id=8193
│ Granule 2: user_id 16385~24576  │ ← 인덱스: user_id=16385
│ ...                             │
└──────────────────────────────────┘

쿼리: WHERE user_id = 10000
→ 인덱스에서 Granule 1에 해당함을 확인 → Granule 1만 읽기
```

**장점**: 인덱스 크기가 매우 작아 메모리에 전부 로드 가능 (수십억 행도 수 MB)

### 파티셔닝

파티셔닝은 데이터를 물리적으로 분리하여 불필요한 파티션을 건너뛰게 한다.

```sql
-- 월 단위 파티셔닝
PARTITION BY toYYYYMM(event_date)

-- 쿼리 시 파티션 프루닝
SELECT COUNT(*) FROM events
WHERE event_date >= '2024-03-01' AND event_date < '2024-04-01'
-- → 202403 파티션만 스캔, 나머지 파티션은 무시
```

### 파트 병합(Merge)

ClickHouse는 데이터 삽입 시 새로운 파트를 생성하고, 백그라운드에서 파트들을 **병합(Merge)**한다.

```
INSERT → Part_1 (100 행)
INSERT → Part_2 (200 행)
INSERT → Part_3 (150 행)
         ↓ 백그라운드 병합
         Part_1_3 (450 행, 정렬됨, 최적화됨)
```

### ReplacingMergeTree (중복 제거)

```sql
CREATE TABLE user_profiles (
    user_id    UInt64,
    name       String,
    email      String,
    updated_at DateTime
)
ENGINE = ReplacingMergeTree(updated_at)  -- updated_at이 가장 큰 행을 유지
ORDER BY user_id;

-- 같은 user_id에 대해 여러 번 INSERT하면
-- 병합 시 updated_at이 가장 최신인 행만 남음
INSERT INTO user_profiles VALUES (1, 'Alice', 'alice@old.com', '2024-01-01 00:00:00');
INSERT INTO user_profiles VALUES (1, 'Alice', 'alice@new.com', '2024-06-01 00:00:00');

-- 최신 데이터만 조회 (병합 전에도 정확한 결과를 위해 FINAL 사용)
SELECT * FROM user_profiles FINAL WHERE user_id = 1;
-- → (1, 'Alice', 'alice@new.com', '2024-06-01 00:00:00')
```

### SummingMergeTree (자동 합산)

```sql
CREATE TABLE daily_stats (
    date        Date,
    page_url    String,
    views       UInt64,
    clicks      UInt64,
    duration    UInt64
)
ENGINE = SummingMergeTree()
ORDER BY (date, page_url);

-- 같은 (date, page_url)로 INSERT하면 병합 시 자동 합산
INSERT INTO daily_stats VALUES ('2024-01-15', '/home', 100, 10, 5000);
INSERT INTO daily_stats VALUES ('2024-01-15', '/home', 200, 20, 8000);

-- 병합 후 결과
-- ('2024-01-15', '/home', 300, 30, 13000)
```

---

## 8. SQL 쿼리 기본

### 데이터베이스 및 테이블 관리

```sql
-- 데이터베이스 생성
CREATE DATABASE analytics;
USE analytics;

-- 테이블 생성
CREATE TABLE page_views (
    timestamp    DateTime,
    user_id      UInt64,
    page_url     String,
    referrer     String,
    country      LowCardinality(String),
    device_type  Enum8('desktop' = 1, 'mobile' = 2, 'tablet' = 3),
    load_time_ms UInt32
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (country, user_id, timestamp);

-- 테이블 구조 확인
DESCRIBE TABLE page_views;
SHOW CREATE TABLE page_views;
```

### 데이터 삽입

```sql
-- 단일 행 삽입
INSERT INTO page_views VALUES
    ('2024-01-15 10:30:00', 12345, '/home', 'https://google.com', 'KR', 'desktop', 150);

-- 다중 행 삽입 (배치 삽입 권장)
INSERT INTO page_views VALUES
    ('2024-01-15 10:30:00', 12345, '/home', '', 'KR', 'mobile', 200),
    ('2024-01-15 10:31:00', 12346, '/about', '', 'US', 'desktop', 120),
    ('2024-01-15 10:32:00', 12347, '/pricing', '', 'JP', 'tablet', 180);

-- SELECT로부터 삽입
INSERT INTO page_views_backup
SELECT * FROM page_views WHERE timestamp >= '2024-01-01';
```

> **중요**: ClickHouse는 **한 번에 하나의 행을 삽입하지 말 것**. 최소 수천~수만 행 단위로 배치 삽입해야 성능이 좋다.

### 분석 쿼리

```sql
-- 국가별 페이지뷰 수
SELECT
    country,
    COUNT(*) AS views,
    uniq(user_id) AS unique_users,
    avg(load_time_ms) AS avg_load_time
FROM page_views
WHERE timestamp >= '2024-01-01' AND timestamp < '2024-02-01'
GROUP BY country
ORDER BY views DESC
LIMIT 10;

-- 시간대별 트래픽 분석
SELECT
    toHour(timestamp) AS hour,
    COUNT(*) AS views,
    bar(COUNT(*), 0, 100000, 40) AS chart  -- 텍스트 차트 생성
FROM page_views
WHERE toDate(timestamp) = '2024-01-15'
GROUP BY hour
ORDER BY hour;

-- 이동 평균 (Window Function)
SELECT
    toDate(timestamp) AS date,
    COUNT(*) AS daily_views,
    avg(COUNT(*)) OVER (ORDER BY toDate(timestamp) ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moving_avg_7d
FROM page_views
GROUP BY date
ORDER BY date;
```

### ClickHouse 전용 함수

```sql
-- uniq: HyperLogLog 기반 근사 고유값 수 (빠르고 메모리 효율적)
SELECT uniq(user_id) FROM page_views;

-- uniqExact: 정확한 고유값 수 (느리지만 정확)
SELECT uniqExact(user_id) FROM page_views;

-- quantile: 분위수 계산
SELECT
    quantile(0.5)(load_time_ms) AS median,
    quantile(0.95)(load_time_ms) AS p95,
    quantile(0.99)(load_time_ms) AS p99
FROM page_views;

-- topK: 상위 K개 값
SELECT topK(10)(page_url) FROM page_views;

-- arrayJoin: 배열을 행으로 펼치기
SELECT arrayJoin([1, 2, 3]) AS num;
-- 결과: 1, 2, 3 (3개 행)

-- 날짜/시간 함수
SELECT
    toStartOfMonth(now()) AS month_start,
    toStartOfWeek(now()) AS week_start,
    toStartOfHour(now()) AS hour_start,
    dateDiff('day', toDate('2024-01-01'), today()) AS days_since;
```

---

## 9. 고급 기능

### Materialized View (물리화된 뷰)

데이터 삽입 시 자동으로 집계 테이블에 데이터를 저장한다. 실시간 집계에 매우 유용하다.

```sql
-- 원본 테이블
CREATE TABLE raw_events (
    timestamp    DateTime,
    user_id      UInt64,
    event_type   String,
    amount       Decimal64(2)
) ENGINE = MergeTree()
ORDER BY (timestamp, user_id);

-- 집계 저장 테이블
CREATE TABLE hourly_stats (
    hour         DateTime,
    event_type   String,
    event_count  UInt64,
    total_amount Decimal64(2),
    unique_users AggregateFunction(uniq, UInt64)
) ENGINE = AggregatingMergeTree()
ORDER BY (hour, event_type);

-- Materialized View (raw_events에 INSERT 시 자동 실행)
CREATE MATERIALIZED VIEW hourly_stats_mv TO hourly_stats AS
SELECT
    toStartOfHour(timestamp) AS hour,
    event_type,
    count() AS event_count,
    sum(amount) AS total_amount,
    uniqState(user_id) AS unique_users
FROM raw_events
GROUP BY hour, event_type;

-- 집계 결과 조회
SELECT
    hour,
    event_type,
    event_count,
    total_amount,
    uniqMerge(unique_users) AS unique_users
FROM hourly_stats
GROUP BY hour, event_type, event_count, total_amount
ORDER BY hour;
```

### Projections (프로젝션)

테이블 내에 다른 정렬 순서의 데이터 사본을 유지하여, 다양한 쿼리 패턴에서 높은 성능을 제공한다.

```sql
CREATE TABLE events (
    timestamp    DateTime,
    user_id      UInt64,
    event_type   String,
    country      String
)
ENGINE = MergeTree()
ORDER BY (user_id, timestamp)
-- 기본 정렬: user_id → timestamp (사용자별 조회 최적화)
;

-- 국가별 조회를 위한 프로젝션 추가
ALTER TABLE events ADD PROJECTION country_projection (
    SELECT * ORDER BY (country, timestamp)
);

-- 프로젝션을 기존 데이터에 적용
ALTER TABLE events MATERIALIZE PROJECTION country_projection;

-- 이제 country 조건의 쿼리도 빠르게 처리됨
SELECT COUNT(*) FROM events WHERE country = 'KR';
-- → country_projection을 자동으로 사용
```

### TTL (Time To Live)

데이터의 자동 만료 및 이동을 설정한다.

```sql
CREATE TABLE logs (
    timestamp    DateTime,
    level        String,
    message      String
)
ENGINE = MergeTree()
ORDER BY timestamp
-- 행 단위 TTL: 30일 후 삭제
TTL timestamp + INTERVAL 30 DAY
-- 컬럼 단위 TTL
SETTINGS merge_with_ttl_timeout = 86400;

-- 스토리지 계층 이동 TTL
CREATE TABLE events (
    timestamp DateTime,
    data      String
)
ENGINE = MergeTree()
ORDER BY timestamp
TTL
    timestamp + INTERVAL 7 DAY TO VOLUME 'warm',     -- 7일 후 warm 스토리지로
    timestamp + INTERVAL 30 DAY TO VOLUME 'cold',    -- 30일 후 cold 스토리지로
    timestamp + INTERVAL 365 DAY DELETE;              -- 1년 후 삭제
```

### Dictionary (딕셔너리)

외부 데이터를 메모리에 로드하여 빠른 조인에 활용한다.

```sql
-- MySQL에서 사용자 정보를 딕셔너리로 로드
CREATE DICTIONARY user_dict (
    user_id UInt64,
    name    String,
    country String
)
PRIMARY KEY user_id
SOURCE(MYSQL(
    host 'mysql-server' port 3306
    db 'app' table 'users'
    user 'reader' password 'pass'
))
LAYOUT(HASHED())
LIFETIME(MIN 300 MAX 600);  -- 5~10분마다 자동 갱신

-- 딕셔너리를 활용한 빠른 조회
SELECT
    user_id,
    dictGet('user_dict', 'name', user_id) AS user_name,
    dictGet('user_dict', 'country', user_id) AS user_country,
    COUNT(*) AS events
FROM raw_events
GROUP BY user_id
ORDER BY events DESC
LIMIT 10;
```

---

## 10. 분산 아키텍처

### 클러스터 구성

ClickHouse는 **샤딩(Sharding)**과 **복제(Replication)**를 통해 분산 클러스터를 구성한다.

```
클러스터 구조:

             ┌─── Distributed 테이블 ───┐
             │  (쿼리 라우팅 / 분산)       │
             └───────────┬───────────────┘
                         │
    ┌────────────────────┼────────────────────┐
    ▼                    ▼                    ▼
┌────────┐         ┌────────┐         ┌────────┐
│ Shard 1│         │ Shard 2│         │ Shard 3│
│┌──────┐│         │┌──────┐│         │┌──────┐│
││Rep 1 ││         ││Rep 1 ││         ││Rep 1 ││
│└──────┘│         │└──────┘│         │└──────┘│
│┌──────┐│         │┌──────┐│         │┌──────┐│
││Rep 2 ││         ││Rep 2 ││         ││Rep 2 ││
│└──────┘│         │└──────┘│         │└──────┘│
└────────┘         └────────┘         └────────┘
```

### Distributed 테이블 설정

```sql
-- 각 샤드(노드)에 로컬 테이블 생성
CREATE TABLE events_local ON CLUSTER my_cluster (
    timestamp    DateTime,
    user_id      UInt64,
    event_type   String
)
ENGINE = ReplicatedMergeTree('/clickhouse/tables/{shard}/events', '{replica}')
PARTITION BY toYYYYMM(timestamp)
ORDER BY (user_id, timestamp);

-- Distributed 테이블 생성 (쿼리 라우터)
CREATE TABLE events_distributed ON CLUSTER my_cluster AS events_local
ENGINE = Distributed(my_cluster, default, events_local, rand());
--                   클러스터명   DB명   로컬테이블명   샤딩키

-- Distributed 테이블에 INSERT → 자동으로 샤드에 분산
INSERT INTO events_distributed VALUES (...);

-- Distributed 테이블에 SELECT → 모든 샤드에서 조회 후 병합
SELECT COUNT(*) FROM events_distributed;
```

### ClickHouse Keeper

ZooKeeper의 대안으로, ClickHouse에 내장된 합의(Consensus) 시스템이다. 복제 메타데이터 관리에 사용된다.

```xml
<!-- config.xml -->
<keeper_server>
    <tcp_port>9181</tcp_port>
    <server_id>1</server_id>
    <raft_configuration>
        <server>
            <id>1</id>
            <hostname>node1</hostname>
            <port>9234</port>
        </server>
        <server>
            <id>2</id>
            <hostname>node2</hostname>
            <port>9234</port>
        </server>
        <server>
            <id>3</id>
            <hostname>node3</hostname>
            <port>9234</port>
        </server>
    </raft_configuration>
</keeper_server>
```

---

## 11. 성능 최적화

### ORDER BY 키 설계

정렬 키는 쿼리 성능에 가장 큰 영향을 미친다.

```sql
-- 나쁜 예: 카디널리티가 높은 컬럼을 앞에 배치
ORDER BY (user_id, timestamp, country)
-- user_id가 매우 다양하여 country 조건 쿼리 시 모든 그래뉼을 스캔

-- 좋은 예: 카디널리티가 낮은 컬럼을 앞에 배치
ORDER BY (country, user_id, timestamp)
-- country 조건 쿼리 시 해당 country의 그래뉼만 스캔
```

**원칙**: WHERE 조건에 자주 사용되는 컬럼을 정렬 키 앞쪽에 배치하되, 카디널리티가 낮은 것부터 높은 순으로 배치한다.

### 데이터 타입 최적화

```sql
-- 나쁜 예
CREATE TABLE bad_example (
    status    String,           -- 'active', 'inactive' (2가지 값에 String 사용)
    country   String,           -- 'KR', 'US' 등 (수십 가지 값에 String 사용)
    is_paid   String,           -- 'true', 'false' (Boolean 대신 String)
    amount    String            -- '12345' (숫자를 String으로 저장)
);

-- 좋은 예
CREATE TABLE good_example (
    status    Enum8('active' = 1, 'inactive' = 2),  -- 1바이트
    country   LowCardinality(String),                -- 사전 인코딩
    is_paid   UInt8,                                 -- 0 또는 1
    amount    UInt32                                  -- 4바이트 정수
);
```

### 배치 삽입

```sql
-- 나쁜 예: 행 단위 삽입 (절대 하지 말 것)
INSERT INTO events VALUES (now(), 1, 'click');
INSERT INTO events VALUES (now(), 2, 'view');
INSERT INTO events VALUES (now(), 3, 'click');
-- → 파트가 3개 생성되어 병합 부하 증가

-- 좋은 예: 배치 삽입 (최소 1000행 이상)
INSERT INTO events VALUES
    (now(), 1, 'click'),
    (now(), 2, 'view'),
    (now(), 3, 'click'),
    ... -- 수천~수만 행
;
-- → 파트 1개 생성
```

### Skip Index (데이터 스키핑 인덱스)

프라이머리 인덱스 외에 추가 인덱스를 설정하여 불필요한 그래뉼을 건너뛸 수 있다.

```sql
CREATE TABLE logs (
    timestamp    DateTime,
    level        LowCardinality(String),
    message      String,
    trace_id     String,

    -- Skip Index 설정
    INDEX idx_trace_id trace_id TYPE bloom_filter(0.01) GRANULARITY 4,
    INDEX idx_level level TYPE set(100) GRANULARITY 4,
    INDEX idx_message message TYPE tokenbf_v1(30720, 2, 0) GRANULARITY 4
)
ENGINE = MergeTree()
ORDER BY timestamp;

-- bloom_filter: 특정 값의 존재 여부를 빠르게 판단 (trace_id 검색)
-- set: 그래뉼 내 고유 값 집합을 저장 (카디널리티가 낮은 컬럼)
-- tokenbf_v1: 텍스트 토큰 검색 (LIKE '%keyword%')
```

---

## 12. 장점과 단점

### 장점

- ✅ **극한의 분석 쿼리 성능** - 수십억 행에 대한 집계를 수 초 만에 처리
- ✅ **높은 압축률** - 컬럼 단위 압축으로 원본 대비 10~40배 압축 가능
- ✅ **높은 삽입 처리량** - 초당 수백만 행 삽입 가능
- ✅ **SQL 호환** - 표준 SQL에 가까운 문법으로 학습 비용이 낮음
- ✅ **수평 확장** - 샤딩과 복제로 데이터와 쿼리를 분산
- ✅ **실시간 데이터 처리** - Materialized View로 삽입과 동시에 집계
- ✅ **오픈소스** - Apache 2.0 라이선스, 활발한 커뮤니티
- ✅ **다양한 통합** - Kafka, S3, MySQL, PostgreSQL 등과 직접 연동 가능

### 단점

- ❌ **UPDATE/DELETE 제한** - 행 단위 업데이트/삭제가 비효율적 (ALTER TABLE ... UPDATE/DELETE 형태로만 가능)
- ❌ **트랜잭션 미지원** - ACID 트랜잭션을 지원하지 않음
- ❌ **포인트 쿼리 비효율** - 단일 행 조회(`WHERE id = 1`)는 OLTP DB보다 느림
- ❌ **JOIN 성능 제한** - 대규모 테이블 간 JOIN은 메모리 소비가 크고 성능이 낮을 수 있음
- ❌ **높은 빈도의 소규모 삽입 부적합** - 배치 삽입이 필수적
- ❌ **운영 복잡도** - 클러스터 구성 시 ZooKeeper/Keeper 관리 필요

---

## 13. 실전 활용 사례

### 로그 분석 시스템

```sql
-- 로그 테이블
CREATE TABLE application_logs (
    timestamp     DateTime64(3),
    service_name  LowCardinality(String),
    level         Enum8('DEBUG' = 0, 'INFO' = 1, 'WARN' = 2, 'ERROR' = 3),
    message       String,
    trace_id      String,
    span_id       String,
    metadata      Map(String, String),

    INDEX idx_trace bloom_filter(0.01) ON trace_id GRANULARITY 4,
    INDEX idx_message tokenbf_v1(30720, 2, 0) ON message GRANULARITY 4
)
ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (service_name, level, timestamp)
TTL timestamp + INTERVAL 30 DAY DELETE
SETTINGS index_granularity = 8192;

-- 서비스별 에러 추이
SELECT
    toStartOfHour(timestamp) AS hour,
    service_name,
    countIf(level = 'ERROR') AS errors,
    countIf(level = 'WARN') AS warnings,
    count() AS total
FROM application_logs
WHERE timestamp >= now() - INTERVAL 24 HOUR
GROUP BY hour, service_name
ORDER BY hour, service_name;
```

### Kafka 연동 실시간 수집

```sql
-- Kafka 엔진 테이블 (소비자)
CREATE TABLE events_kafka (
    timestamp    DateTime,
    user_id      UInt64,
    event_type   String,
    properties   String
)
ENGINE = Kafka()
SETTINGS
    kafka_broker_list = 'kafka1:9092,kafka2:9092',
    kafka_topic_list = 'user_events',
    kafka_group_name = 'clickhouse_consumer',
    kafka_format = 'JSONEachRow',
    kafka_num_consumers = 4;

-- 최종 저장 테이블
CREATE TABLE events (
    timestamp    DateTime,
    user_id      UInt64,
    event_type   LowCardinality(String),
    properties   String
)
ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (event_type, user_id, timestamp);

-- Materialized View로 Kafka → events 자동 전송
CREATE MATERIALIZED VIEW events_consumer TO events AS
SELECT * FROM events_kafka;
```

### Node.js/TypeScript에서 사용

```typescript
import { createClient } from '@clickhouse/client';

const client = createClient({
  url: 'http://localhost:8123',
  username: 'default',
  password: '',
  database: 'analytics',
});

// 데이터 삽입
await client.insert({
  table: 'page_views',
  values: [
    { timestamp: '2024-01-15 10:30:00', user_id: 12345, page_url: '/home', country: 'KR' },
    { timestamp: '2024-01-15 10:31:00', user_id: 12346, page_url: '/about', country: 'US' },
  ],
  format: 'JSONEachRow',
});

// 쿼리 실행
const result = await client.query({
  query: `
    SELECT country, COUNT(*) AS views, uniq(user_id) AS unique_users
    FROM page_views
    WHERE timestamp >= {start:DateTime}
    GROUP BY country
    ORDER BY views DESC
  `,
  query_params: {
    start: '2024-01-01 00:00:00',
  },
  format: 'JSONEachRow',
});

const data = await result.json();
console.log(data);
// [{ country: 'KR', views: '15234', unique_users: '3201' }, ...]
```

---

## 14. 핵심 요약

- ClickHouse는 **컬럼 지향 OLAP 데이터베이스**로, 대규모 데이터의 분석 쿼리에 최적화되어 있다
- **컬럼 단위 저장**으로 필요한 컬럼만 읽고, 높은 압축률과 벡터화 처리를 통해 극한의 성능을 달성한다
- **MergeTree** 엔진이 핵심이며, 희소 인덱스, 파티셔닝, 백그라운드 병합을 통해 데이터를 관리한다
- **Materialized View**를 통해 데이터 삽입과 동시에 실시간 집계가 가능하다
- **INSERT 위주의 워크로드**에 적합하며, UPDATE/DELETE와 트랜잭션은 제한적이다
- **배치 삽입이 필수**이며, 한 번에 최소 수천 행 이상을 삽입해야 한다
- 로그 분석, 이벤트 추적, 실시간 대시보드, 시계열 데이터 등의 사용 사례에 적합하다
- Kafka, S3, MySQL 등과 직접 연동하여 **데이터 파이프라인**을 구성할 수 있다

## 참고 자료

- [ClickHouse 공식 문서](https://clickhouse.com/docs)
- [ClickHouse GitHub 저장소](https://github.com/ClickHouse/ClickHouse)
- [ClickHouse 공식 블로그](https://clickhouse.com/blog)
- [ClickHouse Node.js 클라이언트](https://github.com/ClickHouse/clickhouse-js)
