# Prometheus

## 개요

Prometheus는 SoundCloud에서 개발하고 현재 CNCF(Cloud Native Computing Foundation)에서 관리하는 오픈소스 메트릭 수집 및 모니터링 시스템이다. Pull 기반 모델로 타겟 시스템에서 메트릭을 주기적으로 스크래핑(Scraping)하여 시계열 데이터베이스(TSDB)에 저장하며, 강력한 쿼리 언어인 PromQL을 제공한다.

<br />

## 주요 특징

- **Pull 기반 메트릭 수집** - HTTP 엔드포인트를 통해 타겟에서 메트릭을 주기적으로 가져옴
- **다차원 데이터 모델** - 메트릭 이름과 Key-Value 레이블로 시계열 데이터 식별
- **PromQL** - 유연한 쿼리 언어로 실시간 집계, 필터링, 연산 가능
- **서비스 디스커버리** - Kubernetes, Consul, DNS 등과 연동하여 자동으로 모니터링 대상 탐지
- **Alertmanager 연동** - 알림 규칙 정의 및 Slack, PagerDuty, Email 등으로 알림 발송
- **로컬 TSDB** - 효율적인 시계열 데이터 저장 및 압축

<br />

## 아키텍처

```
┌──────────────┐     scrape      ┌─────────────────┐
│   Targets    │ ◄───────────── │   Prometheus     │
│ (exporters)  │                 │   Server         │
└──────────────┘                 │                  │
                                 │  ┌────────────┐  │
┌──────────────┐     scrape      │  │   TSDB     │  │
│   App with   │ ◄───────────── │  │ (Storage)  │  │
│   /metrics   │                 │  └────────────┘  │
└──────────────┘                 │                  │
                                 │  ┌────────────┐  │
                                 │  │  PromQL    │  │
                                 │  │  Engine    │  │
                                 │  └────────────┘  │
                                 └────────┬─────────┘
                                          │
                              ┌───────────┼───────────┐
                              ▼           ▼           ▼
                        ┌──────────┐ ┌─────────┐ ┌──────────┐
                        │ Grafana  │ │ Alert   │ │ HTTP API │
                        │          │ │ Manager │ │          │
                        └──────────┘ └─────────┘ └──────────┘
```

<br />

## 주요 메트릭 타입

| 타입 | 설명 | 예시 |
|------|------|------|
| **Counter** | 단조 증가하는 누적 값 | 요청 수, 에러 수 |
| **Gauge** | 증가/감소 가능한 현재 값 | CPU 사용률, 메모리 사용량 |
| **Histogram** | 관측값의 분포 (버킷 기반) | 응답 시간 분포 |
| **Summary** | 관측값의 분위수 (클라이언트 계산) | 요청 지연 시간 분위수 |

<br />

## 설치 및 실행

### Docker로 실행

```yaml
# docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=15d'

volumes:
  prometheus_data:
```

### 기본 설정 (prometheus.yml)

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
```

<br />

## PromQL 기본 예시

```promql
# CPU 사용률 (1분 평균)
rate(node_cpu_seconds_total{mode!="idle"}[1m])

# HTTP 요청 수 (5분간 초당 평균)
rate(http_requests_total[5m])

# 메모리 사용률
(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100

# 95번째 백분위 응답 시간
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```
