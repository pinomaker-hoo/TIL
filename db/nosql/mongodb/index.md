# MongoDB

> MongoDB는 C++로 작성된 오픈소스 문서 지향(Document-Oriented) NoSQL 데이터베이스로, JSON과 유사한 BSON(Binary JSON) 형식으로 데이터를 저장하며, 유연한 스키마와 높은 확장성을 제공한다.

## 목차

1. [MongoDB란 무엇인가?](#1-mongodb란-무엇인가)
2. [핵심 아키텍처](#2-핵심-아키텍처)
3. [설치 및 초기 설정](#3-설치-및-초기-설정)
4. [데이터 모델링](#4-데이터-모델링)
5. [CRUD 연산](#5-crud-연산)
6. [인덱스](#6-인덱스)
7. [Aggregation Framework](#7-aggregation-framework)
8. [트랜잭션](#8-트랜잭션)
9. [복제 (Replica Set)](#9-복제-replica-set)
10. [샤딩 (Sharding)](#10-샤딩-sharding)
11. [성능 최적화](#11-성능-최적화)
12. [보안](#12-보안)
13. [MongoDB 8.0 신기능](#13-mongodb-80-신기능)
14. [RDBMS와 비교](#14-rdbms와-비교)
15. [장점과 단점](#15-장점과-단점)
16. [핵심 요약](#16-핵심-요약)

---

## 1. MongoDB란 무엇인가?

MongoDB는 2009년 10gen(현 MongoDB Inc.)에 의해 처음 릴리스된 **문서 지향 NoSQL 데이터베이스**이다. "humongous(거대한)"에서 이름을 따왔으며, 대규모 데이터를 유연하게 저장하고 처리하는 것을 목표로 설계되었다.

### 핵심 특징

- **문서 지향(Document-Oriented)** - JSON과 유사한 BSON 형식으로 데이터를 저장하며, 스키마가 유연하다
- **수평 확장(Horizontal Scaling)** - 샤딩을 통해 여러 서버에 데이터를 분산 저장
- **고가용성(High Availability)** - Replica Set으로 자동 장애 복구(Failover)를 지원
- **풍부한 쿼리 언어** - Aggregation Pipeline, 텍스트 검색, 지리공간 쿼리 등 지원
- **스키마리스(Schema-less)** - 같은 컬렉션 내에서 서로 다른 구조의 문서를 저장 가능
- **내장 문서(Embedded Document)** - 관련 데이터를 하나의 문서에 중첩하여 JOIN 없이 조회 가능

### 용어 비교 (RDBMS vs MongoDB)

| RDBMS | MongoDB | 설명 |
|-------|---------|------|
| Database | Database | 데이터베이스 |
| Table | Collection | 데이터의 그룹 |
| Row | Document | 개별 데이터 레코드 |
| Column | Field | 데이터 항목 |
| Primary Key | _id | 고유 식별자 |
| JOIN | Embedding / $lookup | 데이터 연결 |
| Index | Index | 검색 최적화 |

---

## 2. 핵심 아키텍처

### 스토리지 엔진

MongoDB는 **WiredTiger**를 기본 스토리지 엔진으로 사용한다 (MongoDB 3.2부터 기본값).

```
클라이언트 요청
       ↓
   mongod 프로세스
       ↓
   WiredTiger 스토리지 엔진
       ↓
   ┌─────────────────────────────┐
   │  캐시 (WiredTiger Cache)     │
   │  - 기본: RAM의 50% - 1GB    │
   │  - B-Tree 인덱스 + 데이터    │
   └─────────────────────────────┘
       ↓
   디스크 (데이터 파일 + 저널)
```

### WiredTiger 주요 특성

- **문서 수준 동시성 제어** - 문서 단위의 잠금으로 높은 동시성 제공
- **압축** - snappy(기본), zlib, zstd 압축을 지원하여 디스크 사용량 절감
- **체크포인트** - 60초마다 디스크에 일관된 스냅샷을 기록
- **저널링(Journaling)** - WAL(Write-Ahead Logging)을 사용하여 장애 시 데이터 복구

### BSON (Binary JSON)

MongoDB는 내부적으로 BSON 형식으로 데이터를 저장한다.

```
JSON:
{
  "name": "홍길동",
  "age": 30,
  "hobbies": ["독서", "등산"]
}

BSON (바이너리 인코딩):
- 타입 정보 포함 (string, int32, array 등)
- 길이 접두사 포함 (빠른 탐색 가능)
- 추가 타입 지원: Date, ObjectId, Decimal128, Binary 등
```

BSON이 JSON보다 나은 점:
- **추가 데이터 타입** - Date, ObjectId, Binary, Decimal128 등 지원
- **빠른 인코딩/디코딩** - 바이너리 형식으로 직렬화 성능 우수
- **필드 탐색 최적화** - 길이 접두사로 불필요한 필드를 건너뛸 수 있음

### ObjectId

MongoDB의 기본 `_id` 필드는 12바이트 ObjectId로 자동 생성된다.

```
ObjectId("507f1f77bcf86cd799439011")

구조 (12바이트):
┌──────────┬──────────┬──────────┬──────────┐
│ 4바이트   │ 5바이트   │ 3바이트   │          │
│ 타임스탬프 │ 랜덤 값   │ 카운터    │          │
└──────────┴──────────┴──────────┴──────────┘

- 타임스탬프: 생성 시각 (초 단위, Unix epoch)
- 랜덤 값: 프로세스별 고유 값
- 카운터: 자동 증가 값
```

ObjectId에서 생성 시각 추출:

```javascript
const id = ObjectId("507f1f77bcf86cd799439011");
id.getTimestamp(); // ISODate("2012-10-17T20:46:31Z")
```

---

## 3. 설치 및 초기 설정

### Ubuntu/Debian

```bash
# GPG 키 추가
curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc | \
  sudo gpg -o /usr/share/keyrings/mongodb-server-8.0.gpg --dearmor

# 저장소 추가 (Ubuntu 22.04)
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] \
  https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/8.0 multiverse" | \
  sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list

# 설치
sudo apt update
sudo apt install -y mongodb-org

# 서비스 시작
sudo systemctl start mongod
sudo systemctl enable mongod

# mongosh 접속
mongosh
```

### macOS (Homebrew)

```bash
brew tap mongodb/brew
brew install mongodb-community@8.0

# 서비스 시작
brew services start mongodb-community@8.0

# mongosh 접속
mongosh
```

### Docker

```bash
docker run -d \
  --name mongodb \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=secret \
  -v mongodata:/data/db \
  mongo:8.0

# mongosh 접속
docker exec -it mongodb mongosh -u admin -p secret
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  mongodb:
    image: mongo:8.0
    container_name: mongodb
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: secret
      MONGO_INITDB_DATABASE: mydb
    volumes:
      - mongodata:/data/db
      - ./init-mongo.js:/docker-entrypoint-initdb.d/init-mongo.js
    command: ["--wiredTigerCacheSizeGB", "1"]

volumes:
  mongodata:
```

### 초기 설정 (mongod.conf)

```yaml
# /etc/mongod.conf
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
  wiredTiger:
    engineConfig:
      cacheSizeGB: 2            # WiredTiger 캐시 크기

systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

net:
  port: 27017
  bindIp: 127.0.0.1            # 외부 접근 시 0.0.0.0

security:
  authorization: enabled        # 인증 활성화

operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100        # 100ms 이상 쿼리 프로파일링
```

---

## 4. 데이터 모델링

### 내장 문서 (Embedded Document)

관련 데이터를 하나의 문서에 중첩하여 저장한다. **1:1** 또는 **1:N (소규모)** 관계에 적합하다.

```javascript
// 사용자 + 주소 (1:1 관계)
{
  _id: ObjectId("..."),
  name: "홍길동",
  email: "hong@example.com",
  address: {                    // 내장 문서
    street: "강남대로 123",
    city: "서울",
    zipCode: "06000"
  },
  phones: [                     // 내장 배열
    { type: "mobile", number: "010-1234-5678" },
    { type: "home", number: "02-1234-5678" }
  ]
}
```

내장 문서를 사용해야 하는 경우:
- 부모와 함께 항상 조회되는 데이터
- 1:1 또는 1:소수(few) 관계
- 자식 데이터가 독립적으로 조회되지 않는 경우

### 참조 (Reference)

별도 컬렉션에 저장하고 `_id`로 참조한다. **1:N (대규모)** 또는 **N:M** 관계에 적합하다.

```javascript
// users 컬렉션
{
  _id: ObjectId("user1"),
  name: "홍길동",
  email: "hong@example.com"
}

// orders 컬렉션
{
  _id: ObjectId("order1"),
  userId: ObjectId("user1"),     // 참조
  items: [
    { productId: ObjectId("prod1"), qty: 2, price: 30000 }
  ],
  totalAmount: 60000,
  orderDate: ISODate("2024-03-15")
}
```

참조를 사용해야 하는 경우:
- 자식 데이터가 독립적으로 조회되는 경우
- 1:다수(many) 관계 (수백 개 이상)
- N:M 관계
- 문서 크기가 16MB 제한에 근접하는 경우

### 데이터 모델링 패턴

```javascript
// 1. Bucket 패턴 (시계열 데이터)
// 매 이벤트마다 문서를 생성하지 않고, 시간 단위로 묶어서 저장
{
  _id: ObjectId("..."),
  sensorId: "sensor001",
  date: ISODate("2024-03-15"),
  readings: [                    // 1시간 단위 버킷
    { time: ISODate("2024-03-15T00:00:00Z"), temp: 22.5, humidity: 45 },
    { time: ISODate("2024-03-15T00:01:00Z"), temp: 22.6, humidity: 44 },
    // ...
  ],
  count: 60,
  avgTemp: 22.55
}

// 2. Extended Reference 패턴
// 자주 조회되는 필드만 내장하여 $lookup 최소화
{
  _id: ObjectId("order1"),
  userId: ObjectId("user1"),
  userName: "홍길동",             // 자주 쓰는 필드만 복사
  userEmail: "hong@example.com",
  items: [...]
}

// 3. Computed 패턴
// 자주 계산되는 값을 미리 저장
{
  _id: ObjectId("product1"),
  name: "무선 키보드",
  reviews: [
    { rating: 5, comment: "좋아요" },
    { rating: 4, comment: "괜찮아요" }
  ],
  totalReviews: 2,               // 미리 계산
  avgRating: 4.5                 // 미리 계산
}
```

---

## 5. CRUD 연산

### Create (삽입)

```javascript
// 단일 문서 삽입
db.users.insertOne({
  name: "홍길동",
  age: 30,
  email: "hong@example.com",
  tags: ["developer", "backend"],
  createdAt: new Date()
});

// 다수 문서 삽입
db.users.insertMany([
  { name: "김철수", age: 25, email: "kim@example.com" },
  { name: "이영희", age: 28, email: "lee@example.com" },
  { name: "박민수", age: 35, email: "park@example.com" }
]);

// ordered: false → 하나가 실패해도 나머지 계속 삽입
db.users.insertMany([...], { ordered: false });
```

### Read (조회)

```javascript
// 전체 조회
db.users.find();

// 조건 조회
db.users.find({ age: { $gte: 25, $lte: 30 } });

// 단일 문서 조회
db.users.findOne({ email: "hong@example.com" });

// 프로젝션 (필드 선택)
db.users.find(
  { age: { $gte: 25 } },
  { name: 1, email: 1, _id: 0 }       // 1: 포함, 0: 제외
);

// 정렬, 제한, 건너뛰기
db.users.find()
  .sort({ age: -1 })                   // 내림차순
  .skip(10)                             // 10개 건너뛰기
  .limit(5);                            // 5개만 조회

// 배열 내 요소 조회
db.users.find({ tags: "developer" });                    // 배열에 포함
db.users.find({ tags: { $all: ["developer", "backend"] } }); // 모두 포함
db.users.find({ tags: { $size: 2 } });                   // 배열 크기

// 내장 문서 조회 (점 표기법)
db.users.find({ "address.city": "서울" });

// 존재 여부
db.users.find({ email: { $exists: true } });

// 정규표현식
db.users.find({ name: { $regex: /^홍/, $options: "i" } });
```

### 비교 연산자

| 연산자 | 설명 | 예시 |
|--------|------|------|
| `$eq` | 같음 | `{ age: { $eq: 30 } }` |
| `$ne` | 같지 않음 | `{ age: { $ne: 30 } }` |
| `$gt` | 초과 | `{ age: { $gt: 25 } }` |
| `$gte` | 이상 | `{ age: { $gte: 25 } }` |
| `$lt` | 미만 | `{ age: { $lt: 30 } }` |
| `$lte` | 이하 | `{ age: { $lte: 30 } }` |
| `$in` | 포함 | `{ role: { $in: ["admin", "user"] } }` |
| `$nin` | 미포함 | `{ role: { $nin: ["guest"] } }` |

### 논리 연산자

```javascript
// AND (기본)
db.users.find({ age: { $gte: 25 }, role: "admin" });

// OR
db.users.find({
  $or: [
    { age: { $lt: 20 } },
    { age: { $gt: 60 } }
  ]
});

// AND + OR 조합
db.users.find({
  role: "user",
  $or: [
    { age: { $lt: 20 } },
    { "address.city": "서울" }
  ]
});

// NOT
db.users.find({ age: { $not: { $gte: 30 } } });
```

### Update (수정)

```javascript
// 단일 문서 수정
db.users.updateOne(
  { email: "hong@example.com" },
  {
    $set: { age: 31, updatedAt: new Date() },     // 필드 설정
    $unset: { tempField: "" },                     // 필드 삭제
    $inc: { loginCount: 1 }                        // 증가
  }
);

// 다수 문서 수정
db.users.updateMany(
  { role: "guest" },
  { $set: { isActive: false } }
);

// 배열 연산
db.users.updateOne(
  { _id: ObjectId("...") },
  {
    $push: { tags: "fullstack" },                  // 배열에 추가
    $addToSet: { tags: "developer" },              // 중복 없이 추가
    $pull: { tags: "intern" },                     // 배열에서 제거
    $pop: { tags: 1 }                              // 마지막 요소 제거 (-1: 첫 번째)
  }
);

// 배열 내 특정 요소 수정 ($ positional operator)
db.users.updateOne(
  { _id: ObjectId("..."), "phones.type": "mobile" },
  { $set: { "phones.$.number": "010-9999-8888" } }
);

// Upsert (없으면 삽입)
db.users.updateOne(
  { email: "new@example.com" },
  { $set: { name: "새 사용자", age: 20 } },
  { upsert: true }
);

// replaceOne (문서 전체 교체)
db.users.replaceOne(
  { email: "hong@example.com" },
  { name: "홍길동", age: 31, email: "hong@example.com" }
);
```

### Delete (삭제)

```javascript
// 단일 문서 삭제
db.users.deleteOne({ email: "hong@example.com" });

// 다수 문서 삭제
db.users.deleteMany({ isActive: false });

// 컬렉션 내 모든 문서 삭제
db.users.deleteMany({});

// 컬렉션 자체 삭제
db.users.drop();
```

---

## 6. 인덱스

### 단일 필드 인덱스

```javascript
// 오름차순 인덱스
db.users.createIndex({ email: 1 });

// 내림차순 인덱스
db.orders.createIndex({ orderDate: -1 });

// 유니크 인덱스
db.users.createIndex({ email: 1 }, { unique: true });
```

### 복합 인덱스 (Compound Index)

```javascript
// 복합 인덱스 (필드 순서가 중요!)
db.orders.createIndex({ userId: 1, orderDate: -1 });

// ESR 규칙 (Equality → Sort → Range)
// 1. 등호 조건 필드를 앞에
// 2. 정렬 필드를 중간에
// 3. 범위 조건 필드를 뒤에
db.orders.createIndex({ status: 1, orderDate: -1, amount: 1 });
// → status = "completed" AND amount > 10000 ORDER BY orderDate DESC
```

### 멀티키 인덱스 (배열)

```javascript
// 배열 필드에 인덱스 → 자동으로 멀티키 인덱스 생성
db.users.createIndex({ tags: 1 });

// 배열 내 요소 검색 시 인덱스 사용
db.users.find({ tags: "developer" });
```

### 텍스트 인덱스

```javascript
// 텍스트 인덱스 생성
db.articles.createIndex({
  title: "text",
  content: "text"
}, {
  weights: { title: 10, content: 1 },     // 가중치
  default_language: "korean"               // 기본 언어
});

// 텍스트 검색
db.articles.find({ $text: { $search: "MongoDB 데이터베이스" } });

// 텍스트 점수로 정렬
db.articles.find(
  { $text: { $search: "MongoDB" } },
  { score: { $meta: "textScore" } }
).sort({ score: { $meta: "textScore" } });
```

### 지리공간 인덱스

```javascript
// 2dsphere 인덱스 (GeoJSON)
db.stores.createIndex({ location: "2dsphere" });

// GeoJSON 형식으로 저장
db.stores.insertOne({
  name: "강남점",
  location: {
    type: "Point",
    coordinates: [127.0276, 37.4979]      // [경도, 위도]
  }
});

// 근처 검색 (반경 1km)
db.stores.find({
  location: {
    $near: {
      $geometry: { type: "Point", coordinates: [127.0276, 37.4979] },
      $maxDistance: 1000                   // 미터 단위
    }
  }
});
```

### TTL 인덱스 (자동 만료)

```javascript
// 30일 후 자동 삭제
db.sessions.createIndex(
  { createdAt: 1 },
  { expireAfterSeconds: 2592000 }          // 30일 = 2592000초
);

// 특정 시각에 만료
db.events.createIndex(
  { expireAt: 1 },
  { expireAfterSeconds: 0 }                // expireAt 필드의 값이 만료 시각
);
```

### Partial 인덱스 (부분 인덱스)

```javascript
// 조건에 맞는 문서만 인덱싱
db.orders.createIndex(
  { orderDate: 1 },
  { partialFilterExpression: { status: "active" } }
);
// → 인덱스 크기 절감, status가 "active"인 문서만 인덱싱
```

### 인덱스 관리

```javascript
// 인덱스 목록 확인
db.users.getIndexes();

// 인덱스 사용 통계
db.users.aggregate([{ $indexStats: {} }]);

// 인덱스 삭제
db.users.dropIndex("email_1");
db.users.dropIndex({ email: 1 });

// 모든 인덱스 삭제 (_id 제외)
db.users.dropIndexes();

// 백그라운드 인덱스 생성 (4.2+에서는 기본)
db.users.createIndex({ name: 1 }, { background: true });
```

---

## 7. Aggregation Framework

Aggregation Pipeline은 MongoDB의 데이터 처리 프레임워크로, 여러 스테이지를 파이프라인으로 연결하여 데이터를 변환하고 분석한다.

### 기본 구조

```javascript
db.collection.aggregate([
  { $stage1: { ... } },
  { $stage2: { ... } },
  { $stage3: { ... } }
]);
```

### 주요 스테이지

```javascript
// $match - 필터링 (WHERE)
{ $match: { status: "active", age: { $gte: 18 } } }

// $group - 그룹화 (GROUP BY)
{
  $group: {
    _id: "$department",                    // 그룹 키
    totalSalary: { $sum: "$salary" },
    avgAge: { $avg: "$age" },
    count: { $sum: 1 },
    maxSalary: { $max: "$salary" },
    employees: { $push: "$name" }          // 배열로 수집
  }
}

// $project - 필드 선택/변환 (SELECT)
{
  $project: {
    name: 1,
    upperName: { $toUpper: "$name" },
    yearOfBirth: { $subtract: [2024, "$age"] },
    fullAddress: { $concat: ["$address.city", " ", "$address.street"] }
  }
}

// $sort - 정렬 (ORDER BY)
{ $sort: { totalSalary: -1 } }

// $limit / $skip - 페이지네이션
{ $skip: 20 }
{ $limit: 10 }

// $unwind - 배열 펼치기
{ $unwind: "$tags" }
// { tags: ["a", "b"] } → { tags: "a" }, { tags: "b" }

// $lookup - JOIN
{
  $lookup: {
    from: "orders",                        // 조인할 컬렉션
    localField: "_id",                     // 현재 컬렉션 필드
    foreignField: "userId",                // 대상 컬렉션 필드
    as: "userOrders"                       // 결과 배열 필드명
  }
}

// $addFields - 필드 추가
{
  $addFields: {
    totalPrice: { $multiply: ["$price", "$quantity"] },
    discountedPrice: {
      $cond: {
        if: { $gte: ["$quantity", 10] },
        then: { $multiply: ["$price", 0.9] },
        else: "$price"
      }
    }
  }
}

// $facet - 다중 파이프라인 (한 번의 조회로 여러 결과)
{
  $facet: {
    totalCount: [{ $count: "count" }],
    data: [{ $skip: 0 }, { $limit: 10 }],
    categoryStats: [
      { $group: { _id: "$category", count: { $sum: 1 } } }
    ]
  }
}
```

### 실전 예제

```javascript
// 월별 매출 집계
db.orders.aggregate([
  { $match: { orderDate: { $gte: ISODate("2024-01-01") } } },
  {
    $group: {
      _id: {
        year: { $year: "$orderDate" },
        month: { $month: "$orderDate" }
      },
      totalRevenue: { $sum: "$amount" },
      orderCount: { $sum: 1 },
      avgOrderValue: { $avg: "$amount" }
    }
  },
  { $sort: { "_id.year": 1, "_id.month": 1 } },
  {
    $project: {
      _id: 0,
      period: {
        $concat: [
          { $toString: "$_id.year" }, "-",
          { $toString: "$_id.month" }
        ]
      },
      totalRevenue: { $round: ["$totalRevenue", 0] },
      orderCount: 1,
      avgOrderValue: { $round: ["$avgOrderValue", 0] }
    }
  }
]);

// 사용자별 최근 주문 3건 조회
db.users.aggregate([
  {
    $lookup: {
      from: "orders",
      let: { userId: "$_id" },
      pipeline: [
        { $match: { $expr: { $eq: ["$userId", "$$userId"] } } },
        { $sort: { orderDate: -1 } },
        { $limit: 3 }
      ],
      as: "recentOrders"
    }
  }
]);
```

---

## 8. 트랜잭션

MongoDB 4.0부터 **다중 문서 트랜잭션**을 지원한다. Replica Set 또는 Sharded Cluster 환경에서 사용 가능하다.

### 기본 사용법

```javascript
// mongosh에서 트랜잭션 사용
const session = db.getMongo().startSession();
session.startTransaction({
  readConcern: { level: "snapshot" },
  writeConcern: { w: "majority" }
});

try {
  const accounts = session.getDatabase("bank").accounts;

  // 계좌 이체
  accounts.updateOne(
    { accountId: "A001" },
    { $inc: { balance: -50000 } },
    { session }
  );
  accounts.updateOne(
    { accountId: "A002" },
    { $inc: { balance: 50000 } },
    { session }
  );

  session.commitTransaction();
} catch (error) {
  session.abortTransaction();
  throw error;
} finally {
  session.endSession();
}
```

### Node.js 드라이버에서 트랜잭션

```javascript
const { MongoClient } = require('mongodb');

async function transferMoney(fromId, toId, amount) {
  const client = new MongoClient(uri);
  const session = client.startSession();

  try {
    await session.withTransaction(async () => {
      const accounts = client.db("bank").collection("accounts");

      // 잔액 확인
      const fromAccount = await accounts.findOne(
        { accountId: fromId },
        { session }
      );
      if (fromAccount.balance < amount) {
        throw new Error("잔액 부족");
      }

      // 이체 실행
      await accounts.updateOne(
        { accountId: fromId },
        { $inc: { balance: -amount } },
        { session }
      );
      await accounts.updateOne(
        { accountId: toId },
        { $inc: { balance: amount } },
        { session }
      );
    });
  } finally {
    await session.endSession();
    await client.close();
  }
}
```

### Read/Write Concern

```javascript
// Read Concern 수준
"local"       // 기본값. 로컬 데이터 반환 (복제 보장 없음)
"available"   // 샤딩에서 사용. 가장 빠르지만 고아 문서 가능
"majority"    // 과반수에 복제된 데이터만 반환
"snapshot"    // 트랜잭션 내에서 일관된 스냅샷 보장

// Write Concern 수준
{ w: 1 }          // 기본값. Primary에 기록되면 성공
{ w: "majority" } // 과반수 노드에 복제되면 성공
{ w: 0 }          // 응답 대기 없이 즉시 반환 (fire-and-forget)
{ j: true }       // 저널에 기록되면 성공
```

---

## 9. 복제 (Replica Set)

Replica Set은 동일한 데이터를 유지하는 mongod 인스턴스 그룹으로, **고가용성**과 **데이터 내구성**을 제공한다.

### 구조

```
┌──────────────────────────────────────────────┐
│                Replica Set                    │
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Primary  │  │Secondary │  │Secondary │   │
│  │  (R/W)   │  │  (Read)  │  │  (Read)  │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │    oplog 복제 │              │         │
│       └──────────────┘──────────────┘         │
└──────────────────────────────────────────────┘

- Primary: 모든 쓰기 작업을 처리
- Secondary: Primary의 oplog를 복제하여 동기화
- 자동 Failover: Primary 장애 시 Secondary 중 하나가 자동 승격
```

### 설정

```javascript
// Replica Set 초기화
rs.initiate({
  _id: "myReplicaSet",
  members: [
    { _id: 0, host: "mongo1:27017", priority: 2 },     // 높은 우선순위
    { _id: 1, host: "mongo2:27017", priority: 1 },
    { _id: 2, host: "mongo3:27017", priority: 1 }
  ]
});

// 상태 확인
rs.status();

// 멤버 추가
rs.add("mongo4:27017");

// Arbiter 추가 (투표만 참여, 데이터 미보유)
rs.addArb("mongo5:27017");
```

### Read Preference

```javascript
// 읽기 분산 설정
"primary"             // 기본값. Primary에서만 읽기
"primaryPreferred"    // Primary 우선, 불가능 시 Secondary
"secondary"           // Secondary에서만 읽기
"secondaryPreferred"  // Secondary 우선, 불가능 시 Primary
"nearest"             // 네트워크 지연 시간이 가장 짧은 노드

// Node.js에서 설정
const collection = client.db("mydb").collection("users");
const cursor = collection.find({}).readPref("secondaryPreferred");
```

---

## 10. 샤딩 (Sharding)

샤딩은 데이터를 여러 서버에 분산 저장하여 **수평 확장**을 실현한다.

### 구조

```
┌──────────────────────────────────────────────┐
│              Application                      │
└──────────────┬───────────────────────────────┘
               ↓
┌──────────────────────────────────────────────┐
│           mongos (Query Router)               │
│   - 쿼리를 적절한 샤드로 라우팅                   │
│   - 여러 샤드의 결과를 병합                       │
└──────────────┬───────────────────────────────┘
               ↓
┌──────────────────────────────────────────────┐
│        Config Server (Replica Set)            │
│   - 샤드 메타데이터 (어떤 데이터가 어디에?)        │
│   - 클러스터 설정 정보                           │
└──────────────┬───────────────────────────────┘
               ↓
    ┌──────────┼──────────┐
    ↓          ↓          ↓
┌────────┐ ┌────────┐ ┌────────┐
│ Shard1 │ │ Shard2 │ │ Shard3 │
│  (RS)  │ │  (RS)  │ │  (RS)  │
└────────┘ └────────┘ └────────┘
  각 샤드는 Replica Set으로 구성
```

### 샤드 키 선택

```javascript
// 샤딩 활성화
sh.enableSharding("mydb");

// 해시 샤드 키 (균등 분배)
sh.shardCollection("mydb.users", { _id: "hashed" });

// 범위 샤드 키 (범위 쿼리에 유리)
sh.shardCollection("mydb.logs", { timestamp: 1 });

// 복합 샤드 키
sh.shardCollection("mydb.orders", { userId: 1, orderDate: 1 });
```

### 좋은 샤드 키의 조건

| 조건 | 설명 |
|------|------|
| 높은 카디널리티 | 고유 값이 많아야 함 (성별 같은 저카디널리티 ✗) |
| 균등한 분포 | 데이터가 특정 샤드에 몰리지 않아야 함 |
| 쿼리 격리 | 대부분의 쿼리가 특정 샤드에서만 실행되도록 |
| 단조 증가 방지 | 타임스탬프만 사용하면 마지막 샤드에 쓰기 집중 (핫스팟) |

---

## 11. 성능 최적화

### explain()

```javascript
// 실행 계획 확인
db.users.find({ email: "hong@example.com" }).explain("executionStats");

// 주요 확인 포인트
{
  "executionStats": {
    "nReturned": 1,                         // 반환된 문서 수
    "executionTimeMillis": 0,               // 실행 시간 (ms)
    "totalKeysExamined": 1,                 // 인덱스 키 스캔 수
    "totalDocsExamined": 1,                 // 문서 스캔 수
    "executionStages": {
      "stage": "IXSCAN",                   // IXSCAN: 인덱스 사용
                                            // COLLSCAN: 컬렉션 스캔 (느림)
      "indexName": "email_1"
    }
  }
}
```

핵심 지표:
- **COLLSCAN** → 인덱스 미사용. 인덱스 추가 필요
- **totalDocsExamined >> nReturned** → 불필요한 문서 스캔. 인덱스 또는 쿼리 개선 필요
- **executionTimeMillis** → 실행 시간

### 프로파일러

```javascript
// 프로파일러 활성화 (100ms 이상 쿼리 기록)
db.setProfilingLevel(1, { slowms: 100 });

// 프로파일 데이터 조회
db.system.profile.find().sort({ ts: -1 }).limit(5);

// 프로파일러 비활성화
db.setProfilingLevel(0);
```

### 쿼리 최적화 팁

```javascript
// 1. 커버링 인덱스 사용
db.users.createIndex({ email: 1, name: 1 });
db.users.find({ email: "hong@example.com" }, { name: 1, _id: 0 });
// → 인덱스만으로 결과 반환 (IXSCAN → PROJECTION_COVERED)

// 2. $exists 대신 명시적 값 비교
// 느림: $exists는 인덱스 비효율적
db.users.find({ email: { $exists: true } });
// 빠름: null이 아닌 값
db.users.find({ email: { $ne: null } });

// 3. 정규표현식 앵커 사용
// 느림: 전체 스캔
db.users.find({ name: { $regex: /홍길/ } });
// 빠름: 접두사 매칭 (인덱스 사용)
db.users.find({ name: { $regex: /^홍길/ } });

// 4. 불필요한 $or 대신 $in 사용
// 느림
db.users.find({ $or: [{ status: "A" }, { status: "B" }] });
// 빠름
db.users.find({ status: { $in: ["A", "B"] } });

// 5. 대용량 배열 내장 지양
// 나쁜 예: 댓글이 수만 개가 될 수 있음
{ _id: "post1", comments: [/* 수만 개 */] }
// 좋은 예: 별도 컬렉션으로 분리
{ _id: "comment1", postId: "post1", text: "..." }
```

### Connection Pooling

```javascript
// Node.js 드라이버 연결 풀 설정
const client = new MongoClient(uri, {
  maxPoolSize: 50,                    // 최대 연결 수 (기본 100)
  minPoolSize: 5,                     // 최소 연결 수
  maxIdleTimeMS: 30000,               // 유휴 연결 제거 시간
  waitQueueTimeoutMS: 5000,           // 연결 대기 타임아웃
  connectTimeoutMS: 10000             // 연결 타임아웃
});
```

---

## 12. 보안

### 인증 설정

```javascript
// 관리자 계정 생성
use admin
db.createUser({
  user: "admin",
  pwd: "securePassword",
  roles: [{ role: "root", db: "admin" }]
});

// 애플리케이션 계정 생성
use mydb
db.createUser({
  user: "appUser",
  pwd: "appPassword",
  roles: [
    { role: "readWrite", db: "mydb" },
    { role: "read", db: "analytics" }
  ]
});
```

### 주요 역할 (Role)

| 역할 | 설명 |
|------|------|
| `read` | 읽기 전용 |
| `readWrite` | 읽기 + 쓰기 |
| `dbAdmin` | 인덱스, 통계, 컬렉션 관리 |
| `userAdmin` | 사용자 및 역할 관리 |
| `clusterAdmin` | 클러스터 관리 |
| `root` | 모든 권한 |

### 네트워크 보안

```yaml
# mongod.conf
net:
  bindIp: 127.0.0.1,10.0.0.1     # 허용 IP
  tls:
    mode: requireTLS               # TLS 필수
    certificateKeyFile: /path/to/server.pem
    CAFile: /path/to/ca.pem
```

### 필드 수준 암호화 (CSFLE)

MongoDB 4.2부터 **Client-Side Field Level Encryption**을 지원한다. 민감한 필드를 클라이언트에서 암호화하여 서버에 저장한다.

```javascript
// 암호화 스키마 정의
const encryptedFieldsMap = {
  "mydb.users": {
    fields: [
      {
        path: "ssn",
        bsonType: "string",
        queries: { queryType: "equality" }     // 암호화 상태로 검색 가능
      },
      {
        path: "creditCard",
        bsonType: "string"
      }
    ]
  }
};
```

---

## 13. MongoDB 8.0 신기능

> MongoDB 8.0은 2024년 8월에 릴리스되었다.

### 쿼리 성능 향상

- 복합 인덱스 쿼리 성능이 **최대 20% 향상**
- 대규모 정렬 연산 시 메모리 사용량 최적화
- `$lookup` 스테이지 성능 개선

### Queryable Encryption (GA)

암호화된 데이터에 대해 범위 쿼리가 가능하다.

```javascript
// 암호화된 필드에 대한 범위 쿼리
db.patients.find({
  encryptedAge: { $gte: 30, $lte: 50 }     // 서버는 평문을 볼 수 없음
});
```

### 시계열 컬렉션 개선

```javascript
// 시계열 컬렉션 생성
db.createCollection("metrics", {
  timeseries: {
    timeField: "timestamp",
    metaField: "sensorId",
    granularity: "seconds"
  },
  expireAfterSeconds: 2592000              // 30일 후 자동 삭제
});

// 8.0: 보조 인덱스 성능 향상, 삭제 작업 최적화
```

### 로깅 및 모니터링 개선

```javascript
// 구조화된 로깅 (JSON 형식)
// 슬로우 쿼리 로그에서 쿼리 패턴 자동 해시
{
  "msg": "Slow query",
  "attr": {
    "command": { "find": "users", "filter": { "age": { "$gte": 30 } } },
    "planSummary": "IXSCAN { age: 1 }",
    "durationMillis": 156,
    "queryHash": "ABC123"
  }
}
```

---

## 14. RDBMS와 비교

### 언제 MongoDB를 선택하는가?

| 시나리오 | MongoDB | RDBMS |
|---------|---------|-------|
| 스키마가 자주 변경됨 | O | △ |
| 비정형/반정형 데이터 | O | △ |
| 수평 확장 필요 | O | △ |
| 빠른 프로토타이핑 | O | △ |
| 복잡한 JOIN 필요 | △ | O |
| 엄격한 ACID 필요 | △ | O |
| 복잡한 트랜잭션 | △ | O |
| 데이터 무결성 제약 | △ | O |

### 실전 사용 사례

- **콘텐츠 관리 시스템(CMS)** - 유연한 스키마로 다양한 콘텐츠 타입 관리
- **실시간 분석** - Aggregation Pipeline으로 빠른 데이터 분석
- **IoT 데이터** - 시계열 컬렉션으로 센서 데이터 저장
- **모바일 앱 백엔드** - MongoDB Atlas + Realm으로 오프라인 동기화
- **카탈로그/상품 데이터** - 상품마다 다른 속성을 유연하게 저장
- **사용자 프로필** - 다양한 소셜 로그인 정보를 유연하게 저장
- **게임** - 사용자 상태, 인벤토리 등 복잡한 중첩 데이터 관리

---

## 15. 장점과 단점

### 장점

- **유연한 스키마** - 스키마 변경이 자유롭고, 다양한 구조의 데이터를 하나의 컬렉션에 저장 가능
- **수평 확장** - 샤딩을 통한 자연스러운 수평 확장, 대규모 데이터 처리에 적합
- **높은 성능** - 내장 문서로 JOIN 없이 조회 가능, 쓰기 성능 우수
- **개발 생산성** - JSON 기반 데이터 모델로 애플리케이션 객체와 자연스럽게 매핑
- **풍부한 쿼리** - Aggregation Pipeline, 텍스트 검색, 지리공간 쿼리 등 지원
- **고가용성** - Replica Set으로 자동 장애 복구, 읽기 분산
- **Atlas** - 완전 관리형 클라우드 서비스로 운영 부담 최소화

### 단점

- **JOIN 제한** - `$lookup`이 있지만 RDBMS의 JOIN보다 비효율적
- **메모리 사용량** - BSON 오버헤드로 RDBMS 대비 저장 공간이 더 필요할 수 있음
- **트랜잭션 오버헤드** - 다중 문서 트랜잭션은 RDBMS 대비 성능 오버헤드가 있음
- **데이터 무결성** - 외래 키 제약 조건 미지원, 애플리케이션 레벨에서 관리 필요
- **데이터 중복** - 내장 문서 패턴 사용 시 데이터 중복 발생 가능
- **복잡한 운영** - 샤딩 클러스터 운영은 상당한 전문 지식 필요

---

## 16. 핵심 요약

- MongoDB는 **문서 지향 NoSQL 데이터베이스**로, BSON 형식으로 데이터를 저장하며 유연한 스키마를 제공한다
- **내장 문서(Embedding)**와 **참조(Reference)** 패턴으로 데이터 관계를 모델링한다
- **Aggregation Pipeline**으로 데이터 변환, 그룹화, 분석 등 복잡한 데이터 처리가 가능하다
- **Replica Set**으로 고가용성과 자동 장애 복구를 제공하며, **샤딩**으로 수평 확장이 가능하다
- MongoDB 4.0부터 **다중 문서 트랜잭션**을 지원하며, Read/Write Concern으로 일관성 수준을 조절한다
- **인덱스 전략** (복합, 텍스트, 지리공간, TTL, Partial)이 성능 최적화의 핵심이다
- **ESR 규칙** (Equality → Sort → Range)으로 복합 인덱스를 설계하면 쿼리 성능이 극대화된다
- 스키마가 유연하고, 수평 확장이 필요하며, 빠른 개발이 중요한 프로젝트에 적합하다

## 참고 자료

- [MongoDB 공식 문서](https://www.mongodb.com/docs/)
- [MongoDB University](https://learn.mongodb.com/)
- [MongoDB 8.0 릴리스 노트](https://www.mongodb.com/docs/manual/release-notes/8.0/)
- [MongoDB GitHub](https://github.com/mongodb/mongo)
- [Mongoose ODM](https://mongoosejs.com/)
- [MongoDB Node.js 드라이버](https://www.mongodb.com/docs/drivers/node/current/)
