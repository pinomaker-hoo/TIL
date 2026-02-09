# NestJS에서 사용 가능한 ORM 비교 및 추천

## 목차

- [1. 개요](#1-개요)
- [2. TypeORM](#2-typeorm)
- [3. Prisma](#3-prisma)
- [4. MikroORM](#4-mikroorm)
- [5. Sequelize](#5-sequelize)
- [6. Drizzle ORM](#6-drizzle-orm)
- [7. Knex.js (Query Builder)](#7-knexjs-query-builder)
- [8. 종합 비교](#8-종합-비교)
- [9. 상황별 추천](#9-상황별-추천)

<br />

## 1. 개요

<br />

NestJS는 모듈 기반 아키텍처 덕분에 다양한 ORM과 유연하게 통합할 수 있다. 각 ORM은 설계 철학, 타입 안전성, 성능, 마이그레이션 방식 등에서 뚜렷한 차이를 보인다.

<br />

## 2. TypeORM

<br />

### (1) 개요

TypeORM은 TypeScript/JavaScript용 ORM으로, NestJS 공식 문서에서 가장 먼저 소개하는 ORM이다. `@nestjs/typeorm` 패키지를 통해 공식적인 통합을 지원한다.

```bash
npm install @nestjs/typeorm typeorm pg
```

<br />

### (2) 특징

- **Active Record & Data Mapper 패턴** 모두 지원한다.
- **데코레이터 기반** 엔티티 정의로 NestJS의 스타일과 자연스럽게 어울린다.
- **자동 마이그레이션(synchronize)** 옵션을 제공하여 개발 시 편리하다.
- **CLI 기반 마이그레이션** 생성 및 실행을 지원한다.
- **Relations**: OneToOne, OneToMany, ManyToOne, ManyToMany 관계를 데코레이터로 정의한다.

<br />

### (3) 엔티티 예시

```typescript
@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 100 })
  name: string;

  @Column({ unique: true })
  email: string;

  @OneToMany(() => Post, (post) => post.author)
  posts: Post[];

  @CreateDateColumn()
  createdAt: Date;
}
```

<br />

### (4) NestJS 통합

```typescript
@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'user',
      password: 'password',
      database: 'mydb',
      entities: [User, Post],
      synchronize: false, // 운영 환경에서는 반드시 false
    }),
    TypeOrmModule.forFeature([User]),
  ],
})
export class AppModule {}
```

<br />

### (5) 장단점

| 장점 | 단점 |
| ---- | ---- |
| NestJS 공식 통합 지원 | 복잡한 쿼리에서 타입 안전성이 약하다 |
| 데코레이터 기반으로 NestJS와 스타일 일관 | QueryBuilder 사용 시 타입 추론이 되지 않는다 |
| Active Record / Data Mapper 패턴 선택 가능 | 유지보수 속도가 느리고 이슈 해결이 늦다 |
| 레거시 프로젝트에서 많이 사용되어 레퍼런스가 풍부 | N+1 문제를 직접 관리해야 한다 |
| 다양한 DB 지원 (PostgreSQL, MySQL, SQLite, MSSQL 등) | 대규모 프로젝트에서 성능 이슈가 보고된다 |

<br />

### (6) 지원 DB

PostgreSQL, MySQL, MariaDB, SQLite, MSSQL, Oracle, CockroachDB, MongoDB

<br />

## 3. Prisma

<br />

### (1) 개요

Prisma는 차세대 ORM으로, 스키마 파일(schema.prisma)을 기반으로 타입 안전한 클라이언트를 자동 생성한다. NestJS와 함께 사용할 수 있으며 `@nestjs/prisma` 같은 커뮤니티 패키지도 있지만, PrismaService를 직접 만들어 사용하는 것이 일반적이다.

```bash
npm install prisma @prisma/client
npx prisma init
```

<br />

### (2) 특징

- **Schema-first 접근**: `.prisma` 파일에서 스키마를 정의하고 클라이언트를 생성한다.
- **완전한 타입 안전성**: 생성된 클라이언트가 모든 쿼리에 대해 정확한 타입을 제공한다.
- **Prisma Migrate**: 선언적 마이그레이션 시스템을 제공한다.
- **Prisma Studio**: 데이터를 GUI로 탐색할 수 있는 도구를 제공한다.
- **자동 완성**: 쿼리 작성 시 IDE에서 강력한 자동 완성을 지원한다.

<br />

### (3) 스키마 예시

```prisma
// schema.prisma
model User {
  id        Int      @id @default(autoincrement())
  name      String   @db.VarChar(100)
  email     String   @unique
  posts     Post[]
  createdAt DateTime @default(now())
}

model Post {
  id       Int    @id @default(autoincrement())
  title    String
  author   User   @relation(fields: [authorId], references: [id])
  authorId Int
}
```

<br />

### (4) NestJS 통합

```typescript
// prisma.service.ts
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}

// user.service.ts
@Injectable()
export class UserService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.user.findMany({
      include: { posts: true },
    });
  }
}
```

<br />

### (5) 장단점

| 장점 | 단점 |
| ---- | ---- |
| 최고 수준의 타입 안전성과 자동 완성 | 스키마 변경 시 `prisma generate` 실행이 필요하다 |
| 직관적인 쿼리 API | Raw SQL 사용이 다소 불편하다 |
| Prisma Studio로 데이터 시각화 | 복잡한 집계 쿼리가 제한적이다 |
| 선언적 마이그레이션 시스템 | 런타임 오버헤드가 존재한다 (Query Engine) |
| 활발한 개발과 커뮤니티 | Data Mapper 패턴을 직접 지원하지 않는다 |

<br />

### (6) 지원 DB

PostgreSQL, MySQL, MariaDB, SQLite, MSSQL, CockroachDB, MongoDB

<br />

## 4. MikroORM

<br />

### (1) 개요

MikroORM은 TypeScript 기반 ORM으로 Data Mapper, Unit of Work, Identity Map 패턴을 핵심으로 채택하고 있다. `@mikro-orm/nestjs` 패키지를 통해 NestJS와 공식적으로 통합된다.

```bash
npm install @mikro-orm/core @mikro-orm/nestjs @mikro-orm/postgresql
```

<br />

### (2) 특징

- **Unit of Work 패턴**: 트랜잭션 내 변경 사항을 자동으로 추적하고 일괄 flush한다.
- **Identity Map**: 같은 트랜잭션 내에서 동일 엔티티를 중복 조회하지 않는다.
- **데코레이터 또는 EntitySchema**: 두 가지 방식으로 엔티티를 정의할 수 있다.
- **자동 트랜잭션 관리**: RequestContext를 통해 요청 단위의 EntityManager를 제공한다.

<br />

### (3) 엔티티 예시

```typescript
@Entity()
export class User {
  @PrimaryKey()
  id!: number;

  @Property({ length: 100 })
  name!: string;

  @Property({ unique: true })
  email!: string;

  @OneToMany(() => Post, (post) => post.author)
  posts = new Collection<Post>(this);

  @Property()
  createdAt: Date = new Date();
}
```

<br />

### (4) 장단점

| 장점 | 단점 |
| ---- | ---- |
| Unit of Work로 자동 변경 추적 및 일괄 저장 | TypeORM/Prisma 대비 커뮤니티가 작다 |
| Identity Map으로 중복 쿼리 방지 | 국내 레퍼런스가 적다 |
| 타입 안전한 쿼리 빌더 | Unit of Work 패턴의 학습이 필요하다 |
| NestJS 공식 통합 패키지 제공 | flush 타이밍을 이해해야 한다 |
| 활발한 유지보수 | - |

<br />

### (5) 지원 DB

PostgreSQL, MySQL, MariaDB, SQLite, MongoDB, MSSQL

<br />

## 5. Sequelize

<br />

### (1) 개요

Sequelize는 Node.js에서 가장 오래된 ORM 중 하나로, `@nestjs/sequelize` 패키지를 통해 NestJS와 통합된다. JavaScript 시절부터 사용되어 왔으며 TypeScript 지원이 추가되었다.

```bash
npm install @nestjs/sequelize sequelize sequelize-typescript pg
```

<br />

### (2) 특징

- **Promise 기반 API**: 모든 쿼리가 Promise로 반환된다.
- **데코레이터 기반 모델 정의**: sequelize-typescript를 통해 데코레이터로 모델을 정의한다.
- **마이그레이션 CLI**: sequelize-cli를 통해 마이그레이션을 관리한다.
- **Raw Query 지원**: 복잡한 쿼리를 Raw SQL로 작성할 수 있다.

<br />

### (3) 장단점

| 장점 | 단점 |
| ---- | ---- |
| 오랜 역사와 안정성 | TypeScript 지원이 후발적이라 타입 안전성이 약하다 |
| NestJS 공식 통합 패키지 | 데코레이터 사용 시 sequelize-typescript 의존 |
| 풍부한 레퍼런스와 문서 | TypeORM이나 Prisma 대비 DX가 떨어진다 |
| 다양한 DB 지원 | 최신 트렌드와 거리가 있다 |

<br />

### (4) 지원 DB

PostgreSQL, MySQL, MariaDB, SQLite, MSSQL, DB2, Snowflake

<br />

## 6. Drizzle ORM

<br />

### (1) 개요

Drizzle ORM은 비교적 최신 ORM으로, SQL에 가까운 문법과 가벼운 런타임이 특징이다. NestJS와의 공식 통합 패키지는 없지만 Service로 감싸서 사용할 수 있다.

```bash
npm install drizzle-orm pg
npm install -D drizzle-kit
```

<br />

### (2) 특징

- **SQL-like 문법**: 쿼리가 실제 SQL과 유사하여 SQL에 익숙한 개발자에게 직관적이다.
- **제로 런타임 오버헤드**: 별도의 Query Engine 없이 직접 SQL을 생성한다.
- **완전한 타입 안전성**: TypeScript의 타입 시스템을 최대한 활용한다.
- **가벼운 번들 크기**: 런타임 의존성이 최소화되어 있다.
- **Drizzle Kit**: 마이그레이션 생성 및 관리 도구를 제공한다.

<br />

### (3) 스키마 예시

```typescript
import { pgTable, serial, varchar, timestamp, integer } from 'drizzle-orm/pg-core';

export const users = pgTable('users', {
  id: serial('id').primaryKey(),
  name: varchar('name', { length: 100 }).notNull(),
  email: varchar('email', { length: 255 }).notNull().unique(),
  createdAt: timestamp('created_at').defaultNow(),
});

export const posts = pgTable('posts', {
  id: serial('id').primaryKey(),
  title: varchar('title', { length: 255 }).notNull(),
  authorId: integer('author_id').references(() => users.id),
});
```

<br />

### (4) 쿼리 예시

```typescript
// SQL-like 문법
const result = await db
  .select()
  .from(users)
  .where(eq(users.email, 'test@example.com'));

// Relational Query 문법
const result = await db.query.users.findMany({
  with: { posts: true },
});
```

<br />

### (5) 장단점

| 장점 | 단점 |
| ---- | ---- |
| SQL에 가까운 직관적 문법 | NestJS 공식 통합 패키지가 없다 |
| 제로 런타임 오버헤드 | 상대적으로 신생 ORM이라 생태계가 성장 중이다 |
| 가벼운 번들 크기 | 데코레이터 방식이 아니라 NestJS 스타일과 다소 이질적이다 |
| 타입 안전한 쿼리 | 복잡한 관계 매핑이 다른 ORM 대비 불편할 수 있다 |
| 빠른 성능 | - |

<br />

### (6) 지원 DB

PostgreSQL, MySQL, SQLite, Turso

<br />

## 7. Knex.js (Query Builder)

<br />

### (1) 개요

Knex.js는 ORM이 아닌 Query Builder다. SQL을 프로그래밍적으로 작성할 수 있게 해주며, 별도의 엔티티 매핑 계층이 없다. ORM의 추상화 없이 SQL에 가깝게 작업하고 싶을 때 사용한다.

```bash
npm install knex pg
```

<br />

### (2) 장단점

| 장점 | 단점 |
| ---- | ---- |
| SQL에 대한 완전한 제어 | 엔티티 매핑이 없어 직접 구현해야 한다 |
| 가볍고 빠르다 | 관계 관리를 직접 해야 한다 |
| 마이그레이션 도구 내장 | ORM 대비 보일러플레이트가 많다 |
| 복잡한 쿼리 작성에 유리 | TypeScript 타입 지원이 제한적이다 |

Knex.js는 ORM이 불필요하거나, 복잡한 SQL을 직접 작성해야 하는 프로젝트에 적합하다. Objection.js라는 ORM이 Knex.js 위에 구축되어 있어 함께 사용하기도 한다.

<br />

## 8. 종합 비교

<br />

### (1) 핵심 비교표

| 항목 | TypeORM | Prisma | MikroORM | Sequelize | Drizzle |
| ---- | ------- | ------ | -------- | --------- | ------- |
| NestJS 공식 통합 | O | X (직접 구현) | O | O | X (직접 구현) |
| 타입 안전성 | 보통 | 매우 높음 | 높음 | 낮음 | 매우 높음 |
| 학습 난이도 | 낮음 | 낮음 | 중간 | 낮음 | 낮음 |
| 런타임 성능 | 보통 | 보통 | 좋음 | 보통 | 매우 좋음 |
| 커뮤니티 규모 | 매우 큼 | 매우 큼 | 중간 | 큼 | 성장 중 |
| 유지보수 활발도 | 느림 | 매우 활발 | 활발 | 보통 | 매우 활발 |
| 패턴 | AR / DM | 독자적 | DM / UoW | AR | 독자적 |
| 마이그레이션 | CLI | Prisma Migrate | CLI | CLI | Drizzle Kit |

> AR = Active Record, DM = Data Mapper, UoW = Unit of Work

<br />

### (2) npm 다운로드 수 기준 인기도 (2025년 기준)

| ORM | 주간 다운로드 |
| --- | ------------- |
| Prisma (@prisma/client) | ~350만+ |
| Sequelize | ~200만+ |
| TypeORM | ~200만+ |
| Knex.js | ~180만+ |
| Drizzle ORM | ~60만+ |
| MikroORM | ~10만+ |

<br />

## 9. 상황별 추천

<br />

### (1) 신규 프로젝트 (추천: Prisma)

새로 시작하는 프로젝트라면 **Prisma**를 추천한다.

- 타입 안전성이 가장 뛰어나 런타임 오류를 컴파일 시점에 잡을 수 있다.
- 스키마 파일이 DB 구조의 단일 진실 공급원(Single Source of Truth) 역할을 한다.
- 직관적인 API와 자동 완성으로 생산성이 높다.
- 마이그레이션 관리가 편리하다.
- 활발한 개발이 지속되고 있다.

<br />

### (2) 성능 중시 프로젝트 (추천: Drizzle ORM)

SQL에 익숙하고 성능이 중요하다면 **Drizzle ORM**을 추천한다.

- 제로 런타임 오버헤드로 가장 빠른 성능을 보인다.
- SQL-like 문법으로 생성되는 쿼리를 예측하기 쉽다.
- 번들 크기가 가장 작다.

<br />

### (3) DDD / 클린 아키텍처 프로젝트 (추천: MikroORM)

도메인 주도 설계를 적용하는 프로젝트라면 **MikroORM**을 추천한다.

- Unit of Work 패턴으로 트랜잭션 내 변경 사항을 자동 추적한다.
- Identity Map으로 엔티티의 일관성을 보장한다.
- Data Mapper 패턴을 핵심으로 사용하여 도메인 로직과 영속성 계층을 분리하기 좋다.

<br />

### (4) 기존 TypeORM 프로젝트

이미 TypeORM을 사용 중이라면 무리하게 마이그레이션할 필요는 없다. 다만 신규 모듈이나 서비스를 추가할 때 Prisma 또는 Drizzle로의 점진적 전환을 고려할 수 있다.

<br />

### (5) 종합 추천 요약

| 상황 | 추천 ORM | 이유 |
| ---- | -------- | ---- |
| 신규 프로젝트, 빠른 개발 | Prisma | 타입 안전성, DX, 생산성 |
| 성능 최우선 | Drizzle ORM | 제로 런타임 오버헤드, 경량 |
| DDD / 클린 아키텍처 | MikroORM | Unit of Work, Data Mapper |
| NestJS 입문 / 학습 | TypeORM | 공식 통합, 풍부한 레퍼런스 |
| 레거시 JS 프로젝트 | Sequelize | 안정성, 호환성 |
| SQL 직접 제어 필요 | Knex.js | Query Builder, 완전한 SQL 제어 |
