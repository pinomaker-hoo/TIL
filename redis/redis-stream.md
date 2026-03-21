# Redis Stream

## 1. Redis Stream이란?

Redis Stream은 Redis 5.0에서 도입된 로그형 데이터 구조로, append-only 방식으로 메시지를 저장한다. Kafka와 유사한 개념의 소비자 그룹(Consumer Group)을 지원하며, 기존 Pub/Sub의 한계를 보완하여 안정적인 메시지 처리를 제공한다.

<br />

## 2. Pub/Sub과의 차이점

기존 Redis Pub/Sub은 Fire-and-Forget 방식으로 메시지를 전달하기 때문에 여러 한계가 있다. Redis Stream은 이를 보완한다.

| 구분 | Pub/Sub | Stream |
| --- | --- | --- |
| 메시지 영속성 | 없음 (메모리에만 존재) | 있음 (디스크에 저장 가능) |
| 메시지 보관 | 전달 후 즉시 소멸 | 명시적으로 삭제할 때까지 보관 |
| 구독자 부재 시 | 메시지 소실 | 메시지 보존, 이후 소비 가능 |
| 소비자 그룹 | 미지원 | 지원 |
| 메시지 재처리 | 불가능 | 가능 (ID 기반 조회) |
| ACK 메커니즘 | 없음 | 있음 (XACK) |
| 메시지 순서 보장 | 보장하지 않음 | ID 기반으로 보장 |

<br />

## 3. Stream 기본 구조

Redis Stream은 시간 순서대로 정렬된 메시지(Entry)들의 집합이다. 각 메시지는 고유한 ID와 하나 이상의 필드-값 쌍으로 구성된다.

```
Stream Key: orders
┌──────────────────────────────────────────────────┐
│ ID: 1690000000000-0  │ action: "create" item: "A" │
│ ID: 1690000000001-0  │ action: "update" item: "B" │
│ ID: 1690000000002-0  │ action: "delete" item: "C" │
└──────────────────────────────────────────────────┘
```

### 메시지 ID

메시지 ID는 `<밀리초 타임스탬프>-<시퀀스 번호>` 형식이다. `*`를 사용하면 Redis가 자동으로 ID를 생성한다.

```bash
XADD orders * action "create" item "book"
# 결과: "1690000000000-0"

XADD orders * action "update" item "pen"
# 결과: "1690000000001-0"
```

- 타임스탬프는 밀리초 단위이며 같은 밀리초 내에서는 시퀀스 번호가 증가한다.
- ID는 항상 단조 증가하여 메시지의 시간 순서가 보장된다.

<br />

## 4. 기본 명령어

### (1) 메시지 추가 - XADD

Stream에 새로운 메시지를 추가한다.

```bash
# 자동 ID 생성
XADD mystream * name "pinomaker" action "login"

# 수동 ID 지정
XADD mystream 1690000000000-0 name "pinomaker" action "login"

# Stream 최대 길이 제한 (정확히 1000개)
XADD mystream MAXLEN 1000 * name "pinomaker" action "login"

# 대략적 최대 길이 제한 (성능 최적화, ~ 사용)
XADD mystream MAXLEN ~ 1000 * name "pinomaker" action "login"
```

### (2) 메시지 조회 - XRANGE / XREVRANGE

ID 범위를 기반으로 메시지를 조회한다.

```bash
# 전체 메시지 조회 (- : 최소, + : 최대)
XRANGE mystream - +

# 특정 시간 범위 조회
XRANGE mystream 1690000000000 1690000001000

# 최신 N개 조회 (역순)
XREVRANGE mystream + - COUNT 10

# 개수 제한
XRANGE mystream - + COUNT 5
```

### (3) 메시지 수 확인 - XLEN

```bash
XLEN mystream    # Stream에 저장된 메시지 수
```

### (4) 실시간 대기 읽기 - XREAD

새로운 메시지가 도착할 때까지 블로킹하며 대기할 수 있다.

```bash
# 논블로킹: 특정 ID 이후의 메시지 조회
XREAD COUNT 10 STREAMS mystream 0

# 블로킹: 새 메시지가 올 때까지 최대 5초 대기
XREAD BLOCK 5000 COUNT 10 STREAMS mystream $

# 여러 Stream 동시 읽기
XREAD BLOCK 0 COUNT 10 STREAMS stream1 stream2 $ $
```

- `$`: 현재 시점 이후의 새 메시지만 읽기
- `0`: 처음부터 모든 메시지 읽기
- `BLOCK 0`: 무한 대기

### (5) 메시지 삭제 - XDEL / XTRIM

```bash
# 특정 메시지 삭제
XDEL mystream 1690000000000-0

# Stream 길이 제한 (오래된 메시지부터 삭제)
XTRIM mystream MAXLEN 1000

# 대략적 트리밍 (성능 최적화)
XTRIM mystream MAXLEN ~ 1000

# 특정 ID 이전 메시지 삭제
XTRIM mystream MINID 1690000000000-0
```

<br />

## 5. Consumer Group (소비자 그룹)

Consumer Group은 Redis Stream의 핵심 기능으로, 여러 소비자가 하나의 Stream을 분산하여 처리할 수 있게 한다. Kafka의 Consumer Group과 유사한 개념이다.

### Consumer Group의 동작 원리

```
Stream: orders
┌─────────────────────────────────────────┐
│ msg1 │ msg2 │ msg3 │ msg4 │ msg5 │ msg6 │
└─────────────────────────────────────────┘
          │
    Consumer Group: order-workers
    ┌─────────────────────────────┐
    │ Consumer A ← msg1, msg4    │
    │ Consumer B ← msg2, msg5    │
    │ Consumer C ← msg3, msg6    │
    └─────────────────────────────┘
```

- 같은 그룹 내의 소비자들은 메시지를 중복 없이 분배받는다.
- 서로 다른 그룹은 독립적으로 동일한 메시지를 소비할 수 있다.
- 각 그룹은 자체적인 last_delivered_id를 관리하여 어디까지 전달했는지 추적한다.

### (1) Consumer Group 생성

```bash
# Stream의 처음부터 소비
XGROUP CREATE mystream mygroup 0

# 현재 시점 이후의 새 메시지만 소비
XGROUP CREATE mystream mygroup $

# Stream이 없으면 자동 생성
XGROUP CREATE mystream mygroup 0 MKSTREAM
```

### (2) 메시지 소비 - XREADGROUP

```bash
# consumer1이 mygroup에서 메시지 읽기
XREADGROUP GROUP mygroup consumer1 COUNT 10 STREAMS mystream >

# 블로킹 대기 (새 메시지가 올 때까지 최대 5초)
XREADGROUP GROUP mygroup consumer1 BLOCK 5000 COUNT 10 STREAMS mystream >

# 아직 ACK하지 않은 자신의 보류(Pending) 메시지 재조회
XREADGROUP GROUP mygroup consumer1 COUNT 10 STREAMS mystream 0
```

- `>`: 아직 어떤 소비자에게도 전달되지 않은 새 메시지만 읽기
- `0`: 해당 소비자에게 전달되었지만 아직 ACK되지 않은 메시지 읽기

### (3) 메시지 확인(ACK) - XACK

메시지를 성공적으로 처리했음을 알린다. ACK된 메시지는 Pending 목록에서 제거된다.

```bash
XACK mystream mygroup 1690000000000-0
XACK mystream mygroup 1690000000000-0 1690000000001-0  # 여러 개 동시 ACK
```

### (4) Pending 메시지 관리

ACK되지 않은 메시지를 조회하고 관리할 수 있다.

```bash
# Pending 메시지 요약 정보
XPENDING mystream mygroup

# Pending 메시지 상세 조회
XPENDING mystream mygroup - + 10

# 특정 소비자의 Pending 메시지
XPENDING mystream mygroup - + 10 consumer1
```

### (5) 메시지 소유권 이전 - XCLAIM

장애가 발생한 소비자의 Pending 메시지를 다른 소비자에게 이전할 수 있다.

```bash
# 60초 이상 Pending 상태인 메시지를 consumer2에게 이전
XCLAIM mystream mygroup consumer2 60000 1690000000000-0

# XAUTOCLAIM: 자동으로 오래된 Pending 메시지 이전 (Redis 6.2+)
XAUTOCLAIM mystream mygroup consumer2 60000 0 COUNT 10
```

<br />

## 6. 메시지 처리 흐름

전체적인 메시지 처리 흐름은 다음과 같다.

```
1. Producer가 XADD로 메시지 추가
        ↓
2. Consumer Group이 메시지를 소비자들에게 분배
        ↓
3. 소비자가 XREADGROUP으로 메시지 수신
        ↓
4. 메시지 처리 (비즈니스 로직)
        ↓
5-a. 처리 성공 → XACK로 확인
5-b. 처리 실패 → Pending 목록에 남음
        ↓
6. 장애 소비자의 Pending 메시지 → XCLAIM으로 다른 소비자에게 이전
```

<br />

## 7. Pub/Sub vs Stream 선택 기준

### Pub/Sub이 적합한 경우

- 실시간 알림, 채팅 등 즉시성이 중요한 경우
- 메시지 손실이 허용되는 경우
- 간단한 브로드캐스트가 필요한 경우

### Stream이 적합한 경우

- 메시지 손실이 허용되지 않는 경우 (주문 처리, 결제 등)
- 메시지 재처리가 필요한 경우
- 여러 소비자가 분산 처리해야 하는 경우
- 메시지 처리 상태를 추적해야 하는 경우
- 이벤트 소싱 패턴을 구현하는 경우

<br />

## 8. Stream 사용 시 주의사항

- **메모리 관리**: Stream은 메시지를 계속 보관하므로 `MAXLEN` 또는 `MINID`를 사용하여 오래된 메시지를 정리해야 한다. 그렇지 않으면 메모리가 지속적으로 증가한다.

- **Pending 메시지 모니터링**: ACK되지 않은 메시지가 계속 쌓이면 메모리 문제가 발생할 수 있으므로 주기적으로 `XPENDING`을 확인하고 장애 소비자의 메시지를 `XCLAIM`으로 이전해야 한다.

- **Consumer Group 관리**: 더 이상 사용하지 않는 소비자는 `XGROUP DELCONSUMER`로 제거하여 불필요한 Pending 목록이 남지 않도록 한다.

- **MAXLEN ~ 사용 권장**: 정확한 `MAXLEN`보다 `MAXLEN ~`을 사용하면 Redis가 내부적으로 효율적인 트리밍을 수행하여 성능이 향상된다.

- **Kafka와의 차이**: Redis Stream은 Kafka에 비해 처리량과 내구성에서 한계가 있다. 대규모 이벤트 스트리밍이 필요하다면 Kafka를 고려해야 하며, 중소규모의 메시지 처리에는 Redis Stream이 적합하다.
