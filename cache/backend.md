# Backend 캐시 (API 서버 캐싱)

> API 서버에서 캐시를 활용하여 성능을 최적화하고 데이터베이스 부하를 줄이는 방법을 정리한다.

<br />

## 목차

1. [HTTP 캐시 헤더](#1-http-캐시-헤더)
2. [서버 사이드 캐싱](#2-서버-사이드-캐싱)
3. [NestJS에서의 캐시 적용](#3-nestjs에서의-캐시-적용)
4. [API 응답 캐싱 패턴](#4-api-응답-캐싱-패턴)
5. [DB 쿼리 캐싱](#5-db-쿼리-캐싱)
6. [캐시 무효화 전략](#6-캐시-무효화-전략)
7. [실전 예제: NestJS + Redis](#7-실전-예제-nestjs--redis)

<br />

---

## 1. HTTP 캐시 헤더

HTTP 캐시는 서버와 클라이언트 사이에서 응답을 재사용하여 네트워크 요청을 줄이는 표준 메커니즘이다.

### (1) Cache-Control

HTTP 캐시 동작을 제어하는 핵심 헤더이다.

| 디렉티브 | 설명 |
| --- | --- |
| public | 공유 캐시(CDN, 프록시)에 저장 가능 |
| private | 브라우저 캐시에만 저장 (개인 데이터) |
| no-cache | 캐시 저장은 하되, 사용 전 반드시 서버에 검증 요청 |
| no-store | 어떤 캐시에도 저장하지 않음 |
| max-age=N | N초 동안 캐시를 유효하게 취급 |
| s-maxage=N | 공유 캐시(CDN)에서 N초 동안 유효 (max-age보다 우선) |
| must-revalidate | 만료된 캐시는 반드시 서버에 검증 후 사용 |
| stale-while-revalidate=N | 만료 후 N초 동안 오래된 데이터를 제공하면서 백그라운드에서 갱신 |

### (2) ETag

응답 데이터의 고유 식별자로, 데이터 변경 여부를 검증하는 데 사용한다.

```
서버 응답:
  HTTP/1.1 200 OK
  ETag: "abc123"
  Cache-Control: max-age=3600

클라이언트 재요청 (만료 후):
  GET /api/products/1
  If-None-Match: "abc123"

서버 응답 (변경 없음):
  HTTP/1.1 304 Not Modified

서버 응답 (변경됨):
  HTTP/1.1 200 OK
  ETag: "def456"
  { ... 새 데이터 ... }
```

### (3) Last-Modified / If-Modified-Since

날짜 기반으로 데이터 변경 여부를 확인하는 방식이다. ETag보다 정밀도가 낮지만(초 단위) 구현이 단순하다.

### (4) 조건부 요청 흐름

```
클라이언트                         서버
    │                                │
    ├── GET /api/data ──────────────→│
    │                                ├── 200 OK + ETag: "v1"
    │←───────────────────────────────┤    Cache-Control: max-age=60
    │                                │
    │   ... 60초 경과 (캐시 만료) ...   │
    │                                │
    ├── GET /api/data ──────────────→│
    │   If-None-Match: "v1"          ├── 데이터 변경 확인
    │                                │
    │←── 304 Not Modified ───────────┤  (변경 없음: 본문 없이 응답)
    │    또는                         │
    │←── 200 OK + ETag: "v2" ────────┤  (변경됨: 새 데이터 전송)
```

### (5) NestJS에서 HTTP 캐시 헤더 설정

```typescript
@Get('products/:id')
async getProduct(
  @Param('id') id: string,
  @Res({ passthrough: true }) res: Response,
) {
  const product = await this.productService.findOne(id);

  res.set({
    'Cache-Control': 'public, max-age=3600',
    'ETag': `"${product.updatedAt.getTime()}"`,
  });

  return product;
}
```

<br />

## 2. 서버 사이드 캐싱

### (1) In-Memory 캐시

애플리케이션 프로세스 내부 메모리에 데이터를 저장하는 방식이다.

```typescript
// 단순한 Map 기반 캐시
const cache = new Map<string, { data: unknown; expiry: number }>();

function getFromCache<T>(key: string): T | null {
  const item = cache.get(key);
  if (!item) return null;
  if (Date.now() > item.expiry) {
    cache.delete(key);
    return null;
  }
  return item.data as T;
}

function setCache(key: string, data: unknown, ttlMs: number): void {
  cache.set(key, { data, expiry: Date.now() + ttlMs });
}
```

### (2) Redis

외부 분산 캐시 서버로, 여러 애플리케이션 인스턴스에서 공유할 수 있다. 상세한 내용은 [Redis 문서](../redis/redis.md)를 참고한다.

### (3) 비교

| 특성 | In-Memory | Redis | Memcached |
| --- | --- | --- | --- |
| 공유 범위 | 단일 프로세스 | 다중 서버 공유 | 다중 서버 공유 |
| 데이터 구조 | 자유 (JS 객체) | String, Hash, List, Set 등 | String만 |
| 영속성 | 없음 (프로세스 종료 시 소멸) | RDB/AOF 지원 | 없음 |
| 네트워크 비용 | 없음 | 있음 | 있음 |
| 성능 | 가장 빠름 | 빠름 (~1ms) | 빠름 |
| 메모리 제한 | 프로세스 힙 메모리 | 별도 서버 메모리 | 별도 서버 메모리 |
| 적합한 경우 | 단일 인스턴스, 소규모 데이터 | 다중 인스턴스, 복잡한 캐싱 | 단순 Key-Value 캐싱 |

<br />

## 3. NestJS에서의 캐시 적용

### (1) 패키지 설치

```bash
npm install @nestjs/cache-manager cache-manager cache-manager-redis-store redis
```

### (2) CacheModule 설정

```typescript
// app.module.ts
import { CacheModule } from '@nestjs/cache-manager';
import { redisStore } from 'cache-manager-redis-store';

@Module({
  imports: [
    CacheModule.registerAsync({
      isGlobal: true,
      useFactory: async () => ({
        store: await redisStore({
          socket: {
            host: 'localhost',
            port: 6379,
          },
          ttl: 60, // 기본 TTL (초)
        }),
      }),
    }),
  ],
})
export class AppModule {}
```

### (3) CacheInterceptor (자동 캐싱)

컨트롤러에 `CacheInterceptor`를 적용하면 GET 요청의 응답을 자동으로 캐싱한다.

```typescript
import { CacheInterceptor, CacheKey, CacheTTL } from '@nestjs/cache-manager';

@Controller('products')
@UseInterceptors(CacheInterceptor)
export class ProductsController {
  @Get()
  @CacheTTL(30) // 30초 TTL
  @CacheKey('all-products')
  async findAll() {
    return this.productsService.findAll();
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }
}
```

### (4) 수동 캐시 관리 (CACHE_MANAGER)

서비스 레벨에서 직접 캐시를 제어해야 할 때 사용한다.

```typescript
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import { Cache } from 'cache-manager';

@Injectable()
export class ProductsService {
  constructor(
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
    private productRepo: ProductRepository,
  ) {}

  async findOne(id: string): Promise<Product> {
    const cacheKey = `product:${id}`;

    // 1. 캐시 조회
    const cached = await this.cacheManager.get<Product>(cacheKey);
    if (cached) return cached;

    // 2. DB 조회
    const product = await this.productRepo.findOne({ where: { id } });

    // 3. 캐시 저장
    await this.cacheManager.set(cacheKey, product, 3600);

    return product;
  }

  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const product = await this.productRepo.save({ id, ...dto });

    // 캐시 무효화
    await this.cacheManager.del(`product:${id}`);
    await this.cacheManager.del('all-products');

    return product;
  }
}
```

<br />

## 4. API 응답 캐싱 패턴

### (1) 전체 응답 캐싱

API 엔드포인트의 응답 전체를 캐싱한다. 목록 조회, 상세 조회 등에 적합하다.

```typescript
// 캐시 키 설계: {리소스}:{식별자}:{파라미터}
const cacheKey = `products:list:page=${page}&size=${size}&sort=${sort}`;
```

### (2) 부분 캐싱

응답 내에서 비용이 큰 연산 결과만 캐싱한다.

```typescript
async getProductDetail(id: string) {
  const product = await this.productRepo.findOne({ where: { id } });

  // 연관 통계 데이터만 캐싱 (연산 비용이 높음)
  let stats = await this.cacheManager.get(`product-stats:${id}`);
  if (!stats) {
    stats = await this.calculateProductStats(id);
    await this.cacheManager.set(`product-stats:${id}`, stats, 300);
  }

  return { ...product, stats };
}
```

### (3) 조건부 캐싱

특정 조건에서만 캐시를 적용한다.

```typescript
// 인증되지 않은 공개 요청만 캐싱
@UseInterceptors(CacheInterceptor)
@Get('public/products')
async getPublicProducts() {
  return this.productsService.findPublic();
}

// 인증된 사용자의 데이터는 캐싱하지 않음
@Get('my/orders')
async getMyOrders(@CurrentUser() user: User) {
  return this.ordersService.findByUser(user.id);
}
```

### (4) Cache Key 설계

좋은 캐시 키는 고유하면서도 의미가 명확해야 한다.

```
{서비스}:{리소스}:{식별자}:{버전 또는 파라미터}

예시:
  product:detail:123
  product:list:page=1&size=20
  user:profile:456
  search:results:q=keyword&page=1
```

<br />

## 5. DB 쿼리 캐싱

### (1) Service 레벨 캐싱

Repository 조회 결과를 Service에서 캐싱하는 패턴이다. 가장 일반적이고 유연한 방식이다.

```typescript
@Injectable()
export class CategoryService {
  constructor(
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
    private categoryRepo: CategoryRepository,
  ) {}

  async findAll(): Promise<Category[]> {
    const cacheKey = 'categories:all';
    const cached = await this.cacheManager.get<Category[]>(cacheKey);
    if (cached) return cached;

    const categories = await this.categoryRepo.find({
      order: { sortOrder: 'ASC' },
    });

    // 카테고리는 자주 변하지 않으므로 긴 TTL 설정
    await this.cacheManager.set(cacheKey, categories, 86400);

    return categories;
  }
}
```

### (2) TypeORM 쿼리 캐시

TypeORM은 쿼리 레벨에서 캐싱을 지원한다.

```typescript
// ormconfig에서 캐시 활성화
{
  type: 'mysql',
  cache: {
    type: 'redis',
    options: {
      host: 'localhost',
      port: 6379,
    },
    duration: 60000, // 기본 TTL (밀리초)
  }
}
```

```typescript
// 쿼리에서 캐시 사용
const users = await this.userRepository.find({
  cache: {
    id: 'users_list',
    milliseconds: 60000,
  },
});

// QueryBuilder에서 캐시 사용
const products = await this.productRepository
  .createQueryBuilder('product')
  .where('product.isActive = :isActive', { isActive: true })
  .cache('active_products', 60000)
  .getMany();
```

<br />

## 6. 캐시 무효화 전략

### (1) Write-through 무효화

데이터 변경 시 관련 캐시를 즉시 삭제한다.

```typescript
async deleteProduct(id: string): Promise<void> {
  await this.productRepo.delete(id);

  // 관련 캐시 모두 삭제
  await this.cacheManager.del(`product:${id}`);
  await this.cacheManager.del('all-products');
  await this.cacheManager.del(`product-stats:${id}`);
}
```

### (2) 이벤트 기반 무효화

NestJS의 EventEmitter를 활용하여 도메인 이벤트 발생 시 캐시를 무효화한다.

```typescript
// 이벤트 발행
@Injectable()
export class ProductsService {
  constructor(private eventEmitter: EventEmitter2) {}

  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    const product = await this.productRepo.save({ id, ...dto });
    this.eventEmitter.emit('product.updated', { id });
    return product;
  }
}

// 이벤트 구독 및 캐시 무효화
@Injectable()
export class ProductCacheListener {
  constructor(@Inject(CACHE_MANAGER) private cacheManager: Cache) {}

  @OnEvent('product.updated')
  async handleProductUpdated(payload: { id: string }) {
    await this.cacheManager.del(`product:${payload.id}`);
    await this.cacheManager.del('all-products');
  }
}
```

### (3) 패턴 기반 삭제

Redis의 SCAN 명령을 사용하여 특정 패턴의 캐시를 일괄 삭제한다.

```typescript
async invalidateByPattern(pattern: string): Promise<void> {
  const redis = this.cacheManager.store.getClient();
  let cursor = '0';

  do {
    const [nextCursor, keys] = await redis.scan(cursor, 'MATCH', pattern, 'COUNT', 100);
    cursor = nextCursor;

    if (keys.length > 0) {
      await redis.del(...keys);
    }
  } while (cursor !== '0');
}

// 사용 예시: 모든 상품 관련 캐시 삭제
await this.invalidateByPattern('product:*');
```

<br />

## 7. 실전 예제: NestJS + Redis

전체적인 캐시 적용 흐름을 하나의 모듈로 정리한다.

### (1) Module

```typescript
// products.module.ts
@Module({
  imports: [TypeOrmModule.forFeature([Product])],
  controllers: [ProductsController],
  providers: [ProductsService, ProductCacheListener],
})
export class ProductsModule {}
```

### (2) Service (Cache Aside 패턴)

```typescript
// products.service.ts
@Injectable()
export class ProductsService {
  constructor(
    @Inject(CACHE_MANAGER) private cacheManager: Cache,
    @InjectRepository(Product) private productRepo: Repository<Product>,
    private eventEmitter: EventEmitter2,
  ) {}

  async findAll(page: number, size: number): Promise<Product[]> {
    const cacheKey = `products:list:page=${page}&size=${size}`;
    const cached = await this.cacheManager.get<Product[]>(cacheKey);
    if (cached) return cached;

    const products = await this.productRepo.find({
      skip: (page - 1) * size,
      take: size,
      order: { createdAt: 'DESC' },
    });

    await this.cacheManager.set(cacheKey, products, 300);
    return products;
  }

  async findOne(id: string): Promise<Product> {
    const cacheKey = `product:${id}`;
    const cached = await this.cacheManager.get<Product>(cacheKey);
    if (cached) return cached;

    const product = await this.productRepo.findOneOrFail({ where: { id } });
    await this.cacheManager.set(cacheKey, product, 3600);
    return product;
  }

  async create(dto: CreateProductDto): Promise<Product> {
    const product = await this.productRepo.save(dto);
    this.eventEmitter.emit('product.changed');
    return product;
  }

  async update(id: string, dto: UpdateProductDto): Promise<Product> {
    await this.productRepo.update(id, dto);
    const product = await this.productRepo.findOneOrFail({ where: { id } });

    this.eventEmitter.emit('product.changed', { id });
    return product;
  }

  async delete(id: string): Promise<void> {
    await this.productRepo.delete(id);
    this.eventEmitter.emit('product.changed', { id });
  }
}
```

### (3) Controller

```typescript
// products.controller.ts
@Controller('products')
export class ProductsController {
  constructor(private productsService: ProductsService) {}

  @Get()
  async findAll(
    @Query('page', new DefaultValuePipe(1), ParseIntPipe) page: number,
    @Query('size', new DefaultValuePipe(20), ParseIntPipe) size: number,
  ) {
    return this.productsService.findAll(page, size);
  }

  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.productsService.findOne(id);
  }

  @Post()
  async create(@Body() dto: CreateProductDto) {
    return this.productsService.create(dto);
  }

  @Put(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateProductDto) {
    return this.productsService.update(id, dto);
  }

  @Delete(':id')
  async delete(@Param('id') id: string) {
    return this.productsService.delete(id);
  }
}
```

### (4) Cache Listener (이벤트 기반 무효화)

```typescript
// product-cache.listener.ts
@Injectable()
export class ProductCacheListener {
  constructor(@Inject(CACHE_MANAGER) private cacheManager: Cache) {}

  @OnEvent('product.changed')
  async handleProductChanged(payload?: { id: string }) {
    // 개별 상품 캐시 삭제
    if (payload?.id) {
      await this.cacheManager.del(`product:${payload.id}`);
    }

    // 목록 캐시는 패턴 삭제 또는 전체 삭제
    // 간단한 방법: 알려진 키 삭제
    await this.cacheManager.del('products:list:page=1&size=20');
  }
}
```

### 캐시 적용 전후 비교

| 항목 | 캐시 미적용 | 캐시 적용 (Redis) |
| --- | --- | --- |
| 상품 목록 조회 | ~50ms (DB 쿼리) | ~2ms (Cache Hit) |
| 상품 상세 조회 | ~30ms (DB 쿼리) | ~1ms (Cache Hit) |
| DB 부하 (초당 쿼리) | 1000 QPS | ~200 QPS |
| 동시 사용자 처리 | 낮음 | 높음 |
