# Sentry

## 개요

Sentry는 실시간 에러 모니터링 및 성능 추적 플랫폼이다. 애플리케이션에서 발생하는 에러, 예외(Exception), 크래시를 자동으로 수집하고, 스택 트레이스, 사용자 컨텍스트, 브레드크럼 등 상세한 디버깅 정보를 제공한다. JavaScript, Python, Java, Go, .NET, Ruby 등 100개 이상의 플랫폼/프레임워크 SDK를 지원하며, 셀프호스팅과 SaaS 양쪽 모두 사용 가능하다.

<br />

## 주요 특징

- **실시간 에러 추적** - 애플리케이션 에러를 자동 수집, 분류, 알림
- **스택 트레이스 & 소스맵** - 에러 발생 위치를 정확한 코드 라인까지 추적 (소스맵 지원)
- **이슈 그루핑** - 유사한 에러를 자동으로 그룹화하여 중복 알림 방지
- **릴리즈 추적** - 배포 버전별 에러 발생률 변화 추적
- **성능 모니터링** - 트랜잭션 기반 성능 추적, 웹 바이탈(Web Vitals) 모니터링
- **브레드크럼(Breadcrumbs)** - 에러 발생 전 사용자의 행동 기록 추적
- **세션 리플레이** - 사용자의 화면 녹화를 통한 에러 재현 (프론트엔드)

<br />

## 아키텍처

```
┌────────────┐  ┌────────────┐  ┌────────────┐
│  Frontend  │  │  Backend   │  │  Mobile    │
│  (JS SDK)  │  │  (SDK)     │  │  (SDK)     │
└─────┬──────┘  └─────┬──────┘  └─────┬──────┘
      │               │               │
      └───────────────┼───────────────┘
                      ▼
              ┌───────────────┐
              │  Sentry DSN   │
              │  (Endpoint)   │
              └───────┬───────┘
                      ▼
         ┌────────────────────────┐
         │     Sentry Server     │
         │                        │
         │  ┌──────┐ ┌─────────┐  │
         │  │Relay │ │SymbolicA│  │
         │  │      │ │tor      │  │
         │  └──┬───┘ └─────────┘  │
         │     ▼                   │
         │  ┌──────────────────┐  │
         │  │  Event Processing│  │
         │  │  (Grouping,      │  │
         │  │   Filtering)     │  │
         │  └──────────────────┘  │
         └────────────────────────┘
```

<br />

## 설치 및 실행

### 셀프호스팅 (Docker)

```bash
# Sentry 공식 셀프호스팅 저장소 클론
git clone https://github.com/getsentry/self-hosted.git
cd self-hosted

# 설치 스크립트 실행
./install.sh

# 실행
docker compose up -d
```

셀프호스팅 시 기본 포트는 `9000`이며, PostgreSQL, Redis, Kafka, ClickHouse 등이 함께 구동된다.

### SDK 연동 예시

**Node.js (Express)**

```javascript
const Sentry = require('@sentry/node');

Sentry.init({
  dsn: 'https://<key>@sentry.io/<project>',
  tracesSampleRate: 1.0,
  environment: 'production',
  release: '1.0.0',
});

const app = express();

// Sentry 요청 핸들러 (가장 먼저 등록)
app.use(Sentry.Handlers.requestHandler());

// 라우트 정의
app.get('/', (req, res) => {
  res.send('Hello World');
});

// Sentry 에러 핸들러 (에러 핸들러 중 가장 먼저 등록)
app.use(Sentry.Handlers.errorHandler());
```

**React (프론트엔드)**

```javascript
import * as Sentry from '@sentry/react';

Sentry.init({
  dsn: 'https://<key>@sentry.io/<project>',
  integrations: [
    Sentry.browserTracingIntegration(),
    Sentry.replayIntegration(),
  ],
  tracesSampleRate: 1.0,
  replaysSessionSampleRate: 0.1,
});
```

<br />

## Sentry vs 로그 기반 에러 모니터링

| 비교 항목 | Sentry | ELK/Loki (로그 기반) |
|-----------|--------|---------------------|
| 에러 수집 방식 | SDK 자동 수집 | 로그 파일 파싱 |
| 스택 트레이스 | 자동 (소스맵 지원) | 수동 파싱 필요 |
| 이슈 그루핑 | 자동 분류 | 수동 쿼리 |
| 릴리즈 추적 | 내장 지원 | 별도 구현 필요 |
| 알림 | 에러 기반 스마트 알림 | 로그 패턴 기반 |
| 적합한 케이스 | 애플리케이션 에러 관리 | 시스템/인프라 로그 분석 |
