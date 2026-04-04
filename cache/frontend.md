# Frontend 캐시 (프론트엔드 캐싱)

> 프론트엔드에서 캐시를 활용하여 페이지 로딩 속도를 최적화하고 사용자 경험을 개선하는 방법을 정리한다.

<br />

## 목차

1. [브라우저 캐시 동작 원리](#1-브라우저-캐시-동작-원리)
2. [HTTP 캐시 헤더 (브라우저 관점)](#2-http-캐시-헤더-브라우저-관점)
3. [Service Worker 캐싱](#3-service-worker-캐싱)
4. [메모이제이션](#4-메모이제이션)
5. [상태 관리 캐싱](#5-상태-관리-캐싱)
6. [웹 스토리지 캐싱](#6-웹-스토리지-캐싱)
7. [CDN 캐시](#7-cdn-캐시)
8. [캐시 버스팅 전략](#8-캐시-버스팅-전략)

<br />

---

## 1. 브라우저 캐시 동작 원리

브라우저는 여러 계층의 캐시를 사용하여 리소스를 저장하고 재사용한다.

### 캐시 유형 및 우선순위

```
요청 발생
  │
  ├─ 1. Memory Cache (메모리 캐시)
  │     현재 탭이 열려 있는 동안 메모리에 저장
  │     탭 닫으면 소멸 / 가장 빠름
  │
  ├─ 2. Service Worker Cache
  │     Service Worker가 등록된 경우 캐시 API로 관리
  │     오프라인 지원 가능
  │
  ├─ 3. Disk Cache (디스크 캐시)
  │     하드디스크에 저장 / 브라우저 종료 후에도 유지
  │     용량이 크고 지속성 있음
  │
  ├─ 4. Push Cache (HTTP/2)
  │     HTTP/2 서버 푸시로 전송된 리소스
  │     세션 단위로 유지 / 가장 짧은 생명주기
  │
  └─ 5. Network (네트워크 요청)
        캐시에 없으면 서버에 직접 요청
```

Chrome DevTools의 Network 탭에서 Size 열에 `(memory cache)` 또는 `(disk cache)`로 캐시 출처를 확인할 수 있다.

<br />

## 2. HTTP 캐시 헤더 (브라우저 관점)

### (1) 강력한 캐시 (Strong Cache)

서버에 검증 요청 없이 로컬 캐시를 바로 사용하는 방식이다. `Cache-Control: max-age`와 `Expires` 헤더로 제어한다.

### (2) 협상 캐시 (Negotiated Cache)

캐시가 만료된 후 서버에 데이터 변경 여부를 확인(검증)하고, 변경이 없으면 캐시를 계속 사용하는 방식이다. `ETag`/`If-None-Match`와 `Last-Modified`/`If-Modified-Since`를 사용한다.

### (3) 캐시 결정 흐름

```
요청 발생
  │
  ├─ Cache-Control / max-age 확인
  │   ├─ 유효 (만료 전) → 캐시 사용 (200 from cache) ─── 강력한 캐시
  │   └─ 만료 → 서버에 검증 요청 ─────────────────────── 협상 캐시
  │       ├─ ETag → If-None-Match
  │       └─ Last-Modified → If-Modified-Since
  │           ├─ 변경 없음 → 304 Not Modified (캐시 재사용)
  │           └─ 변경됨 → 200 OK + 새 데이터
```

### (4) 리소스별 권장 캐시 설정

| 리소스 타입 | Cache-Control 설정 | 이유 |
| --- | --- | --- |
| HTML | no-cache | 항상 최신 버전을 확인해야 함 |
| JS/CSS (해시 포함) | max-age=31536000, immutable | 파일명에 해시가 포함되어 변경 시 URL이 달라짐 |
| 이미지 | max-age=86400 | 자주 변경되지 않음 |
| API 응답 | no-store 또는 짧은 max-age | 동적 데이터이므로 캐싱에 주의 |
| 폰트 | max-age=31536000 | 거의 변경되지 않음 |

<br />

## 3. Service Worker 캐싱

Service Worker는 브라우저와 네트워크 사이에서 프록시 역할을 하며, 캐시를 세밀하게 제어할 수 있다.

### (1) Cache First (캐시 우선)

캐시에 있으면 캐시를 반환하고, 없으면 네트워크에서 가져온다. 정적 리소스에 적합하다.

```javascript
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((cached) => {
      return cached || fetch(event.request).then((response) => {
        return caches.open('v1').then((cache) => {
          cache.put(event.request, response.clone());
          return response;
        });
      });
    })
  );
});
```

### (2) Network First (네트워크 우선)

네트워크를 먼저 시도하고, 실패하면 캐시를 반환한다. API 요청에 적합하다.

```javascript
self.addEventListener('fetch', (event) => {
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const clone = response.clone();
        caches.open('v1').then((cache) => cache.put(event.request, clone));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
```

### (3) Stale While Revalidate

캐시를 즉시 반환하면서 백그라운드에서 네트워크 요청으로 캐시를 갱신한다. 빠른 응답과 최신 데이터를 모두 확보할 수 있다.

```javascript
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.open('v1').then((cache) => {
      return cache.match(event.request).then((cached) => {
        const fetchPromise = fetch(event.request).then((response) => {
          cache.put(event.request, response.clone());
          return response;
        });
        return cached || fetchPromise;
      });
    })
  );
});
```

### 전략 비교

| 전략 | 응답 속도 | 데이터 최신성 | 오프라인 지원 | 적합한 리소스 |
| --- | --- | --- | --- | --- |
| Cache First | 매우 빠름 | 낮음 | 있음 | 정적 리소스 (이미지, 폰트) |
| Network First | 보통 | 높음 | 있음 (폴백) | API 응답, 동적 콘텐츠 |
| Stale While Revalidate | 빠름 | 보통 | 있음 | 자주 변하는 정적 리소스 |
| Cache Only | 가장 빠름 | 없음 | 있음 | 앱 셸, 오프라인 전용 |
| Network Only | 느림 | 가장 높음 | 없음 | 실시간 데이터 |

<br />

## 4. 메모이제이션

메모이제이션은 연산 결과를 메모리에 캐싱하여 동일한 입력에 대해 재계산을 방지하는 기법이다.

### (1) useMemo

비용이 큰 계산 결과를 메모이제이션한다.

```typescript
const sortedProducts = useMemo(() => {
  return products
    .filter((p) => p.isActive)
    .sort((a, b) => b.price - a.price);
}, [products]);
```

### (2) useCallback

함수 참조를 메모이제이션하여 자식 컴포넌트의 불필요한 리렌더링을 방지한다.

```typescript
const handleClick = useCallback((id: string) => {
  setSelectedId(id);
}, []);

// 자식 컴포넌트에 전달
<ProductList onSelect={handleClick} />
```

### (3) React.memo

컴포넌트 자체를 메모이제이션하여 props가 변경되지 않으면 리렌더링을 건너뛴다.

```typescript
const ProductCard = React.memo(({ product }: { product: Product }) => {
  return (
    <div>
      <h3>{product.name}</h3>
      <p>{product.price}원</p>
    </div>
  );
});
```

### 주의사항

- 모든 곳에 메모이제이션을 적용하면 오히려 성능이 저하될 수 있다. 메모이제이션 자체에도 비용(메모리, 비교 연산)이 발생한다.
- **사용이 적합한 경우**: 비용이 큰 계산, 렌더링이 자주 발생하는 컴포넌트, 참조 동일성이 중요한 경우
- **사용이 불필요한 경우**: 단순한 연산, 매 렌더링마다 값이 변경되는 경우, 의존성 배열이 자주 변하는 경우

<br />

## 5. 상태 관리 캐싱

### (1) TanStack Query (React Query)

서버 상태를 자동으로 캐싱하고 관리하는 라이브러리이다.

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';

// 데이터 조회 + 자동 캐싱
const { data, isLoading } = useQuery({
  queryKey: ['products', id],
  queryFn: () => fetchProduct(id),
  staleTime: 5 * 60 * 1000, // 5분 동안 데이터를 신선한 것으로 취급
  gcTime: 30 * 60 * 1000,   // 30분 동안 비활성 캐시 유지 (GC 대상 아님)
});
```

#### 핵심 개념

- **staleTime**: 데이터가 "신선"하다고 간주하는 기간이다. 이 시간 동안은 재요청해도 캐시를 바로 반환한다.
- **gcTime** (구 cacheTime): 비활성 상태의 캐시 데이터가 메모리에서 제거되기까지의 시간이다.
- **Query Invalidation**: 데이터 변경 후 관련 캐시를 무효화하여 재조회를 트리거한다.

```typescript
const queryClient = useQueryClient();

const mutation = useMutation({
  mutationFn: (dto: UpdateProductDto) => updateProduct(id, dto),
  onSuccess: () => {
    // 관련 캐시 무효화 → 자동으로 재조회 발생
    queryClient.invalidateQueries({ queryKey: ['products'] });
  },
});
```

### (2) SWR

Stale-While-Revalidate 패턴을 기반으로 한 데이터 페칭 라이브러리이다.

```typescript
import useSWR from 'swr';

const fetcher = (url: string) => fetch(url).then((res) => res.json());

const { data, error, isLoading, mutate } = useSWR(
  `/api/products/${id}`,
  fetcher,
  {
    revalidateOnFocus: true,     // 탭 포커스 시 재검증
    revalidateOnReconnect: true, // 네트워크 재연결 시 재검증
    dedupingInterval: 2000,      // 2초 내 중복 요청 방지
  },
);

// 수동 재검증
mutate();
```

### (3) 비교

| 특성 | TanStack Query | SWR | RTK Query |
| --- | --- | --- | --- |
| 캐싱 | 자동 (queryKey 기반) | 자동 (URL 기반) | 자동 (endpoint 기반) |
| Devtools | React Query Devtools | SWR Devtools | Redux Devtools |
| 번들 크기 | ~39KB | ~12KB | Redux 포함 필요 |
| 캐시 무효화 | invalidateQueries | mutate | invalidateTags |
| 낙관적 업데이트 | 지원 | 지원 | 지원 |
| 서버 상태 관리 | 특화 | 특화 | Redux와 통합 |
| 학습 곡선 | 보통 | 낮음 | 높음 (Redux 필요) |

<br />

## 6. 웹 스토리지 캐싱

### (1) LocalStorage

영구적으로 데이터를 저장하며 브라우저를 닫아도 유지된다. 동기 API이다.

```typescript
// 단순 저장/조회
localStorage.setItem('theme', 'dark');
const theme = localStorage.getItem('theme');
```

### (2) SessionStorage

탭 단위로 데이터를 저장하며 탭을 닫으면 소멸된다.

```typescript
sessionStorage.setItem('searchKeyword', 'cache');
const keyword = sessionStorage.getItem('searchKeyword');
```

### (3) IndexedDB

대용량 구조화된 데이터를 저장할 수 있는 비동기 데이터베이스이다.

### (4) 비교

| 특성 | LocalStorage | SessionStorage | IndexedDB |
| --- | --- | --- | --- |
| 용량 | ~5MB | ~5MB | 수백 MB 이상 |
| 지속성 | 영구 | 탭 종료 시 소멸 | 영구 |
| API | 동기 | 동기 | 비동기 |
| 데이터 형태 | 문자열 Key-Value | 문자열 Key-Value | 구조화된 객체 |
| 적합한 용도 | 사용자 설정, 토큰 | 임시 폼 데이터 | 오프라인 데이터, 대용량 캐시 |

### (5) TTL이 있는 LocalStorage 캐시 유틸

LocalStorage는 TTL을 기본 지원하지 않으므로 직접 구현한다.

```typescript
const cacheUtils = {
  set(key: string, data: unknown, ttlMs: number): void {
    const item = {
      data,
      expiry: Date.now() + ttlMs,
    };
    localStorage.setItem(key, JSON.stringify(item));
  },

  get<T>(key: string): T | null {
    const raw = localStorage.getItem(key);
    if (!raw) return null;

    const item = JSON.parse(raw);
    if (Date.now() > item.expiry) {
      localStorage.removeItem(key);
      return null;
    }

    return item.data as T;
  },

  remove(key: string): void {
    localStorage.removeItem(key);
  },
};

// 사용 예시
cacheUtils.set('user-profile', { name: 'pinomaker' }, 60 * 60 * 1000); // 1시간
const profile = cacheUtils.get<{ name: string }>('user-profile');
```

<br />

## 7. CDN 캐시

CDN(Content Delivery Network)은 전 세계에 분산된 엣지 서버에 콘텐츠를 캐싱하여 사용자와 가장 가까운 서버에서 응답한다.

### 동작 원리

```
사용자 (서울)                CDN 엣지 (서울)              Origin 서버 (미국)
     │                           │                            │
     ├── 요청 ─────────────────→ │                            │
     │                           ├── Cache Hit?               │
     │                           │   ├─ Yes → 바로 응답        │
     │                           │   └─ No → Origin 요청 ────→│
     │                           │                            ├── 응답
     │                           │←─────────────────────────── │
     │←── 응답 (캐싱 후 반환) ────┤                            │
```

### CDN 캐시 관련 헤더

| 헤더 | 설명 |
| --- | --- |
| s-maxage | CDN(공유 캐시)의 TTL을 별도로 지정 |
| Surrogate-Control | CDN 전용 캐시 제어 (Fastly 등) |
| CDN-Cache-Control | CDN 전용 캐시 제어 (Cloudflare 등) |
| Vary | 동일 URL이라도 헤더 값에 따라 다른 캐시를 저장 |

### 캐시 퍼지 (Cache Purge)

CDN에 캐싱된 콘텐츠를 강제로 삭제하는 작업이다. 배포 시 또는 긴급 콘텐츠 수정 시 필요하다.

- **전체 퍼지**: 모든 캐시를 삭제한다. 간단하지만 Origin 부하가 급증할 수 있다.
- **선택적 퍼지**: 특정 URL 또는 태그의 캐시만 삭제한다.

<br />

## 8. 캐시 버스팅 (Cache Busting) 전략

정적 리소스에 긴 TTL(1년 등)을 설정하면 성능은 좋아지지만, 코드를 배포해도 사용자가 오래된 캐시를 사용하는 문제가 발생한다. 캐시 버스팅은 이를 해결하는 기법이다.

### (1) 파일명 해싱 (권장)

빌드 시 파일 내용을 기반으로 해시를 생성하여 파일명에 포함한다. 파일 내용이 변경되면 해시가 달라져 새로운 URL로 요청된다.

```
main.js      →  main.a1b2c3d4.js
style.css    →  style.e5f6g7h8.css
```

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name].[hash].js',
        chunkFileNames: 'assets/[name].[hash].js',
        assetFileNames: 'assets/[name].[hash].[ext]',
      },
    },
  },
});
```

### (2) 쿼리 스트링 버전

파일명은 유지하고 쿼리 스트링으로 버전을 관리한다. 일부 CDN은 쿼리 스트링을 무시할 수 있어 주의가 필요하다.

```html
<link rel="stylesheet" href="style.css?v=2.1.0" />
<script src="app.js?v=2.1.0"></script>
```

### (3) 경로 버전

URL 경로에 버전 정보를 포함한다.

```
/v1/style.css  →  /v2/style.css
```

### 비교

| 방식 | CDN 호환성 | 구현 난이도 | 정확성 |
| --- | --- | --- | --- |
| 파일명 해싱 | 좋음 | 빌드 도구 필요 | 높음 (내용 기반) |
| 쿼리 스트링 | 일부 CDN 비호환 | 낮음 | 보통 (수동 관리) |
| 경로 버전 | 좋음 | 보통 | 보통 (수동 관리) |

파일명 해싱이 가장 권장되는 방식이며, Vite와 Webpack 등 현대 빌드 도구에서 기본으로 지원한다.
