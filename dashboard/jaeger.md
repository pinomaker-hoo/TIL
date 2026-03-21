# Jaeger

## 개요

Jaeger는 Uber에서 개발하고 현재 CNCF(Cloud Native Computing Foundation)에서 관리하는 오픈소스 분산 추적(Distributed Tracing) 시스템이다. 마이크로서비스 아키텍처에서 서비스 간 요청 흐름을 추적하여 성능 병목, 장애 원인, 서비스 의존성을 분석할 수 있다. OpenTelemetry와 호환되며 Zipkin 프로토콜도 지원한다.

<br />

## 주요 특징

- **분산 추적(Distributed Tracing)** - 서비스 간 요청 흐름을 엔드투엔드로 추적
- **서비스 의존성 분석** - 서비스 간 호출 관계를 자동으로 시각화 (DAG)
- **성능 최적화** - Span 단위의 지연 시간 분석으로 병목 지점 파악
- **근본 원인 분석** - 장애 발생 시 에러가 전파된 경로 추적
- **OpenTelemetry 호환** - OTLP 프로토콜 네이티브 지원
- **적응형 샘플링** - 트래픽 양에 따라 자동으로 샘플링 비율 조정

<br />

## 핵심 개념

| 용어 | 설명 |
|------|------|
| **Trace** | 하나의 요청이 시스템을 통과하는 전체 경로 |
| **Span** | Trace 내의 개별 작업 단위 (하나의 서비스 호출) |
| **SpanContext** | Trace ID, Span ID 등 추적 정보를 담은 컨텍스트 |
| **Baggage** | Trace 전체에 전파되는 Key-Value 메타데이터 |

<br />

## 아키텍처

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Service A│  │ Service B│  │ Service C│
│ (SDK)    │  │ (SDK)    │  │ (SDK)    │
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
     └─────────────┼─────────────┘
                   ▼
          ┌────────────────┐
          │  Jaeger        │
          │  Collector     │
          │  (OTLP/gRPC)  │
          └───────┬────────┘
                  ▼
         ┌────────────────┐
         │    Storage     │
         │ (Elasticsearch │
         │  / Cassandra / │
         │  Kafka/Badger) │
         └───────┬────────┘
                 ▼
          ┌──────────────┐
          │  Jaeger UI   │
          │  (Query)     │
          └──────────────┘
```

<br />

## 설치 및 실행

### All-in-One (개발/테스트용)

```yaml
# docker-compose.yml
version: '3.8'
services:
  jaeger:
    image: jaegertracing/all-in-one:latest
    container_name: jaeger
    ports:
      - "16686:16686"  # Jaeger UI
      - "4317:4317"    # OTLP gRPC
      - "4318:4318"    # OTLP HTTP
      - "14268:14268"  # Jaeger Thrift HTTP
    environment:
      - COLLECTOR_OTLP_ENABLED=true
```

### OpenTelemetry SDK 연동 예시 (Node.js)

```javascript
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');

const sdk = new NodeSDK({
  traceExporter: new OTLPTraceExporter({
    url: 'http://localhost:4317',
  }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

<br />

## Jaeger vs Zipkin

| 비교 항목 | Jaeger | Zipkin |
|-----------|--------|--------|
| 개발사 | Uber → CNCF | Twitter |
| 언어 | Go | Java |
| UI | 풍부한 시각화 | 심플한 UI |
| 스토리지 | ES, Cassandra, Kafka, Badger | ES, Cassandra, MySQL, In-Memory |
| 샘플링 | 적응형 샘플링 지원 | 고정 비율 |
| OpenTelemetry | 네이티브 지원 | 호환 가능 |
