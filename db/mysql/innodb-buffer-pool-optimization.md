# MySQL InnoDB 버퍼 풀 최적화

> InnoDB 버퍼 풀은 MySQL 성능의 핵심으로, 테이블과 인덱스 데이터를 메모리에 캐싱하여 디스크 I/O를 최소화한다. 버퍼 풀 설정 하나로 전체 시스템 성능이 극적으로 달라질 수 있다.

## 목차

1. [버퍼 풀이란?](#1-버퍼-풀이란)
2. [버퍼 풀 크기 설정](#2-버퍼-풀-크기-설정)
3. [버퍼 풀 내부 구조](#3-버퍼-풀-내부-구조)
4. [버퍼 풀 인스턴스](#4-버퍼-풀-인스턴스)
5. [버퍼 풀 모니터링](#5-버퍼-풀-모니터링)
6. [버퍼 풀 워밍업](#6-버퍼-풀-워밍업)
7. [관련 파라미터 튜닝](#7-관련-파라미터-튜닝)
8. [실전 최적화 가이드](#8-실전-최적화-가이드)

---

## 1. 버퍼 풀이란?

InnoDB 버퍼 풀은 **테이블 데이터와 인덱스 페이지를 메모리에 캐싱**하는 영역이다. 디스크에서 데이터를 읽는 대신 메모리에서 읽으므로 성능이 크게 향상된다.

```
클라이언트 쿼리: SELECT * FROM users WHERE id = 1
                         ↓
                   InnoDB 스토리지 엔진
                         ↓
              ┌──────────────────────┐
              │   버퍼 풀 (메모리)     │
              │                      │
              │  페이지 존재?          │
              │  ├─ YES → 즉시 반환   │  ← 버퍼 풀 히트 (매우 빠름)
              │  └─ NO  → 디스크 읽기  │  ← 버퍼 풀 미스 (느림)
              │          ↓            │
              │    페이지를 버퍼 풀에    │
              │    로드 후 반환        │
              └──────────────────────┘

디스크 읽기: ~10ms (HDD) / ~0.1ms (SSD)
메모리 읽기: ~0.0001ms
→ 메모리가 디스크보다 100~100,000배 빠름
```

### 버퍼 풀이 관리하는 것들

| 항목 | 설명 |
|------|------|
| 데이터 페이지 | 테이블의 행 데이터가 저장된 16KB 페이지 |
| 인덱스 페이지 | B+Tree 인덱스의 노드 페이지 |
| 변경 버퍼 (Change Buffer) | 세컨더리 인덱스 변경을 지연 처리하는 버퍼 |
| 적응형 해시 인덱스 | 자주 접근하는 페이지에 대한 해시 인덱스 (자동 생성) |
| 잠금 정보 | 행 수준 잠금 정보 |

---

## 2. 버퍼 풀 크기 설정

### 기본 원칙

```ini
# my.cnf
[mysqld]
# 전용 DB 서버: 전체 RAM의 70~80%
# 공유 서버: 전체 RAM의 50~60%
innodb_buffer_pool_size = 12G    # 16GB RAM 서버 기준
```

### 메모리 할당 가이드

```
서버 전체 RAM
├── OS + 파일 시스템 캐시: 1~2GB
├── MySQL 서버 자체: ~500MB
├── 연결당 메모리 (sort_buffer, join_buffer 등): 연결 수 × ~10MB
├── InnoDB 버퍼 풀: ← 나머지 대부분
├── InnoDB 로그 버퍼: 64~256MB
└── 기타 버퍼 (tmp_table_size 등)

예시 (16GB RAM, 200 연결):
- OS + 캐시: 2GB
- 연결당 메모리: 200 × 10MB = 2GB
- 기타 버퍼: 0.5GB
- 남은 메모리: 16 - 2 - 2 - 0.5 = 11.5GB
- innodb_buffer_pool_size = 10~12G
```

### 동적 크기 조정 (MySQL 5.7+)

```sql
-- 온라인으로 버퍼 풀 크기 변경 (재시작 불필요)
SET GLOBAL innodb_buffer_pool_size = 12 * 1024 * 1024 * 1024;  -- 12GB

-- 변경 진행 상태 확인
SHOW STATUS LIKE 'Innodb_buffer_pool_resize_status';
```

크기 변경은 **innodb_buffer_pool_chunk_size** (기본 128MB) 단위로 이루어진다.

```
innodb_buffer_pool_size는 다음의 배수여야 함:
innodb_buffer_pool_chunk_size × innodb_buffer_pool_instances

예: chunk_size=128MB, instances=8
→ buffer_pool_size는 1024MB(1GB)의 배수여야 함
```

---

## 3. 버퍼 풀 내부 구조

### LRU (Least Recently Used) 리스트

버퍼 풀은 변형된 LRU 알고리즘으로 페이지를 관리한다.

```
┌──────────────────────────────────────────────┐
│              LRU 리스트                        │
│                                              │
│  ┌────────────────────┐  ┌────────────────┐  │
│  │    New Sublist     │  │  Old Sublist   │  │
│  │    (Young, 5/8)    │  │  (Old, 3/8)    │  │
│  │                    │  │                │  │
│  │  자주 접근하는 페이지  │  │  새로 읽은 페이지 │  │
│  │  (Hot Pages)       │  │  (Cold Pages)  │  │
│  └────────────────────┘  └────────────────┘  │
│           ↑                     ↑             │
│     재접근 시 이동          처음 읽은 페이지는    │
│     (Young → Head)       Old Sublist에 삽입    │
└──────────────────────────────────────────────┘
```

**Midpoint Insertion Strategy:**
1. 새로 읽은 페이지는 **Old Sublist의 Head**에 삽입된다
2. Old Sublist에서 **다시 접근**되면 New Sublist로 이동한다
3. 오래 접근되지 않은 페이지는 LRU 꼬리에서 제거된다

이 전략의 장점: 전체 테이블 스캔 시 한 번만 읽히는 페이지가 자주 쓰이는 **핫 데이터를 밀어내지 않는다**.

### Old Sublist 체류 시간

```ini
# 새 페이지가 Old Sublist에서 최소 1초 이상 머문 후
# 다시 접근되어야 New Sublist로 이동
innodb_old_blocks_time = 1000     # 밀리초 (기본 1000)

# Old Sublist 비율 (기본 3/8 = 37%)
innodb_old_blocks_pct = 37
```

대용량 테이블 스캔이 빈번한 환경에서는 `innodb_old_blocks_time`을 높여서 핫 데이터를 보호한다.

---

## 4. 버퍼 풀 인스턴스

### 멀티 인스턴스

버퍼 풀을 여러 인스턴스로 분할하면 **동시 접근 시 뮤텍스 경합을 줄일 수 있다**.

```ini
# 버퍼 풀 인스턴스 수 (기본 1, 권장 8~16)
# 버퍼 풀 크기가 1GB 이상일 때만 효과적
innodb_buffer_pool_instances = 8

# 예: 12GB 버퍼 풀, 8 인스턴스
# → 각 인스턴스 = 12GB / 8 = 1.5GB
# → 각 인스턴스는 독립적인 LRU 리스트를 가짐
```

### 인스턴스 수 가이드

| 버퍼 풀 크기 | 권장 인스턴스 수 |
|-------------|----------------|
| 1GB 미만 | 1 |
| 1~8GB | 4~8 |
| 8~32GB | 8~16 |
| 32GB 이상 | 16~32 |

---

## 5. 버퍼 풀 모니터링

### 버퍼 풀 히트율 확인

```sql
-- 버퍼 풀 히트율 계산 (99% 이상이면 양호)
SELECT
    (1 - (
        (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_reads')
        /
        (SELECT variable_value FROM performance_schema.global_status WHERE variable_name = 'Innodb_buffer_pool_read_requests')
    )) * 100 AS buffer_pool_hit_ratio;

-- 또는 간단하게
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool%';
```

주요 지표:

| 지표 | 설명 |
|------|------|
| `Innodb_buffer_pool_read_requests` | 버퍼 풀 읽기 요청 수 (논리적 읽기) |
| `Innodb_buffer_pool_reads` | 디스크에서 직접 읽은 수 (물리적 읽기) |
| `Innodb_buffer_pool_pages_total` | 전체 페이지 수 |
| `Innodb_buffer_pool_pages_free` | 여유 페이지 수 |
| `Innodb_buffer_pool_pages_dirty` | 더티 페이지 수 (디스크에 미반영) |
| `Innodb_buffer_pool_wait_free` | 여유 페이지 대기 횟수 (0이어야 정상) |

### 히트율 해석

```
히트율 99% 이상 → 정상. 대부분의 읽기가 메모리에서 처리됨
히트율 95~99%  → 양호. 버퍼 풀 증설을 고려
히트율 95% 미만 → 경고. 버퍼 풀 크기 부족 또는 비효율적 쿼리
```

### InnoDB 엔진 상태 확인

```sql
SHOW ENGINE INNODB STATUS\G

-- BUFFER POOL AND MEMORY 섹션에서 확인
-- Buffer pool size: 786432 (페이지 수 × 16KB = 12GB)
-- Free buffers: 1024
-- Database pages: 780000
-- Old database pages: 287000
-- Modified db pages: 15000   ← 더티 페이지
-- Buffer pool hit rate: 999 / 1000  ← 99.9%
```

### sys 스키마 활용

```sql
-- 버퍼 풀에서 가장 많은 공간을 차지하는 테이블/인덱스
SELECT * FROM sys.innodb_buffer_stats_by_table
ORDER BY allocated DESC
LIMIT 10;

-- 버퍼 풀 내 인덱스별 페이지 수
SELECT * FROM sys.innodb_buffer_stats_by_schema;
```

---

## 6. 버퍼 풀 워밍업

### 문제

MySQL을 재시작하면 버퍼 풀이 비어있어 **콜드 스타트** 상태가 된다. 이후 쿼리들이 모두 디스크에서 읽기를 수행하므로 성능이 일시적으로 저하된다.

### 버퍼 풀 덤프/로드 (MySQL 5.6+)

```ini
# my.cnf
[mysqld]
# 종료 시 버퍼 풀 상태를 파일에 저장
innodb_buffer_pool_dump_at_shutdown = ON

# 시작 시 저장된 버퍼 풀 상태를 복원
innodb_buffer_pool_load_at_startup = ON

# 덤프할 페이지 비율 (기본 25%)
innodb_buffer_pool_dump_pct = 75
```

```sql
-- 수동 덤프 (운영 중에도 가능)
SET GLOBAL innodb_buffer_pool_dump_now = ON;

-- 수동 로드
SET GLOBAL innodb_buffer_pool_load_now = ON;

-- 로드 진행 상태 확인
SHOW STATUS LIKE 'Innodb_buffer_pool_load_status';
-- → Innodb_buffer_pool_load_status: Buffer pool(s) load completed at ...

-- 로드 취소
SET GLOBAL innodb_buffer_pool_load_abort = ON;
```

덤프 파일에는 **테이블스페이스 ID와 페이지 번호**만 저장되므로 파일 크기가 매우 작다 (수 MB). 실제 데이터는 로드 시 디스크에서 읽어온다.

---

## 7. 관련 파라미터 튜닝

### 변경 버퍼 (Change Buffer)

세컨더리 인덱스의 변경을 즉시 반영하지 않고, 버퍼 풀 내 변경 버퍼에 저장해두었다가 나중에 일괄 반영한다.

```ini
# 변경 버퍼 활성화 범위
# none: 비활성화
# inserts: INSERT만
# deletes: DELETE-marking만
# changes: INSERT + DELETE-marking
# purges: 퍼지만
# all: 모두 (기본값)
innodb_change_buffering = all

# 변경 버퍼가 버퍼 풀에서 차지할 수 있는 최대 비율 (기본 25%)
innodb_change_buffer_max_size = 25
```

- **읽기 중심 워크로드**: `innodb_change_buffer_max_size`를 줄여 데이터 캐시 공간 확보
- **쓰기 중심 워크로드**: 기본값 유지 또는 증가

### 적응형 해시 인덱스

InnoDB가 자주 접근하는 인덱스 페이지에 대해 **자동으로 해시 인덱스를 생성**한다.

```ini
# 적응형 해시 인덱스 (기본 ON)
innodb_adaptive_hash_index = ON

# 파티션 수 (동시성 향상, 기본 8)
innodb_adaptive_hash_index_parts = 8
```

모니터링:

```sql
-- 해시 인덱스 사용 통계
SHOW ENGINE INNODB STATUS\G
-- INSERT BUFFER AND ADAPTIVE HASH INDEX 섹션 확인
-- hash searches/s, non-hash searches/s 비교
```

해시 검색 비율이 낮거나 뮤텍스 경합이 심하면 비활성화를 고려한다.

### 로그 버퍼

```ini
# 로그 버퍼 크기 (기본 16MB)
# 대규모 트랜잭션이 많으면 64~256MB로 증가
innodb_log_buffer_size = 64M

# 로그 파일 크기 (기본 48MB × 2개)
# 쓰기가 많은 환경에서는 1~2GB 권장
innodb_redo_log_capacity = 2G        # MySQL 8.0.30+
```

### 플러시 관련

```ini
# 더티 페이지 플러시 비율 (기본 75%)
# 더티 페이지가 이 비율을 초과하면 적극적으로 플러시
innodb_max_dirty_pages_pct = 75

# 저수위 마크 (이 비율 아래이면 플러시 감소)
innodb_max_dirty_pages_pct_lwm = 10

# I/O 용량 (IOPS)
# HDD: 200, SSD: 2000~5000, NVMe: 5000~20000
innodb_io_capacity = 2000            # 일반적인 플러시 IOPS
innodb_io_capacity_max = 4000        # 최대 플러시 IOPS

# 플러시 방법
# O_DIRECT: 이중 버퍼링 방지 (Linux + SSD 권장)
innodb_flush_method = O_DIRECT
```

---

## 8. 실전 최적화 가이드

### 시나리오 1: 16GB RAM, SSD, 읽기 중심

```ini
[mysqld]
innodb_buffer_pool_size = 12G
innodb_buffer_pool_instances = 8
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_load_at_startup = ON
innodb_buffer_pool_dump_pct = 75

innodb_flush_method = O_DIRECT
innodb_io_capacity = 2000
innodb_io_capacity_max = 4000

innodb_change_buffer_max_size = 10   # 읽기 중심이므로 축소
innodb_adaptive_hash_index = ON
innodb_old_blocks_time = 1000
```

### 시나리오 2: 64GB RAM, NVMe, 쓰기 중심

```ini
[mysqld]
innodb_buffer_pool_size = 48G
innodb_buffer_pool_instances = 16
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_load_at_startup = ON
innodb_buffer_pool_dump_pct = 50

innodb_flush_method = O_DIRECT
innodb_io_capacity = 10000
innodb_io_capacity_max = 20000

innodb_redo_log_capacity = 4G
innodb_log_buffer_size = 256M

innodb_change_buffering = all
innodb_change_buffer_max_size = 25
innodb_max_dirty_pages_pct = 90       # 더티 페이지 허용량 증가
```

### 시나리오 3: 4GB RAM, 소규모 서비스

```ini
[mysqld]
innodb_buffer_pool_size = 2G
innodb_buffer_pool_instances = 2
innodb_buffer_pool_dump_at_shutdown = ON
innodb_buffer_pool_load_at_startup = ON

innodb_flush_method = O_DIRECT
innodb_io_capacity = 200
innodb_io_capacity_max = 400

innodb_log_buffer_size = 16M
```

### 점검 체크리스트

```sql
-- 1. 버퍼 풀 히트율 확인 (99% 이상?)
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_read%';

-- 2. 여유 페이지 대기 발생 여부 (0이어야 정상)
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_wait_free';

-- 3. 더티 페이지 비율 확인
SELECT
    (SELECT variable_value FROM performance_schema.global_status
     WHERE variable_name = 'Innodb_buffer_pool_pages_dirty') /
    (SELECT variable_value FROM performance_schema.global_status
     WHERE variable_name = 'Innodb_buffer_pool_pages_total') * 100
AS dirty_pages_pct;

-- 4. 페이지 메이드 영 / 올드 비율
SHOW GLOBAL STATUS LIKE 'Innodb_buffer_pool_pages%';

-- 5. 체크포인트 지연 확인
SHOW ENGINE INNODB STATUS\G
-- → Log sequence number vs Last checkpoint 차이가 크면 플러시 부족
```

---

## 핵심 요약

- InnoDB 버퍼 풀은 **데이터와 인덱스를 메모리에 캐싱**하여 디스크 I/O를 최소화하는 MySQL 성능의 핵심이다
- 버퍼 풀 크기는 전용 서버 기준 **전체 RAM의 70~80%**로 설정하며, 동적 조정이 가능하다
- **Midpoint Insertion** 전략으로 전체 테이블 스캔이 핫 데이터를 밀어내지 않도록 보호한다
- 버퍼 풀을 **여러 인스턴스로 분할**하면 동시 접근 시 뮤텍스 경합이 줄어든다
- **버퍼 풀 히트율은 99% 이상**을 유지해야 하며, `Innodb_buffer_pool_wait_free`는 0이어야 한다
- **버퍼 풀 덤프/로드** 기능으로 재시작 후 콜드 스타트 문제를 해결한다
- `innodb_flush_method = O_DIRECT`, 적절한 `innodb_io_capacity` 설정이 I/O 성능의 핵심이다

## 참고 자료

- [MySQL 공식 문서 - InnoDB Buffer Pool](https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool.html)
- [MySQL 공식 문서 - InnoDB Startup Options](https://dev.mysql.com/doc/refman/8.0/en/innodb-parameters.html)
- [Percona - InnoDB Buffer Pool Tuning](https://www.percona.com/blog/tag/innodb-buffer-pool/)
