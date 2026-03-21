# Loki

## 개요

Loki는 Grafana Labs에서 개발한 수평 확장 가능한 로그 수집 시스템이다. "Prometheus와 같은 방식의 로그 시스템"을 목표로 설계되었으며, 로그 내용을 전문 인덱싱하지 않고 레이블(Label)만 인덱싱하여 저장 비용과 운영 복잡성을 크게 낮춘다. Grafana와의 네이티브 통합을 통해 로그를 쉽게 검색하고 시각화할 수 있다.

<br />

## 주요 특징

- **레이블 기반 인덱싱** - 로그 내용이 아닌 메타데이터(레이블)만 인덱싱하여 저장 비용 절감
- **Prometheus 레이블 호환** - Prometheus와 동일한 레이블 체계로 메트릭-로그 간 상관관계 분석 용이
- **LogQL** - PromQL에서 영감을 받은 로그 쿼리 언어
- **경량 아키텍처** - ELK 대비 매우 낮은 리소스 사용량
- **오브젝트 스토리지 지원** - S3, GCS, Azure Blob 등에 로그 청크 저장 가능
- **Grafana 네이티브 통합** - Grafana 대시보드에서 바로 로그 검색 및 시각화

<br />

## 아키텍처

```
┌───────────┐    push     ┌──────────────────────────┐
│  Promtail │ ──────────► │        Loki              │
│  (Agent)  │             │                          │
└───────────┘             │  ┌────────┐ ┌─────────┐  │
                          │  │ Index  │ │  Chunks │  │
┌───────────┐    push     │  │(BoltDB)│ │  (S3/   │  │
│  Fluentd  │ ──────────► │  │        │ │  GCS)   │  │
│ /Fluent   │             │  └────────┘ └─────────┘  │
│  Bit      │             └────────────┬─────────────┘
└───────────┘                          │
                                       ▼
                                ┌──────────────┐
                                │   Grafana    │
                                │  (LogQL)     │
                                └──────────────┘
```

<br />

## Loki vs ELK Stack

| 비교 항목 | Loki | ELK Stack |
|-----------|------|-----------|
| 인덱싱 방식 | 레이블만 인덱싱 | 로그 전문 인덱싱 |
| 저장 비용 | 매우 낮음 | 높음 |
| 리소스 사용량 | 낮음 | 높음 (Elasticsearch 메모리) |
| 검색 성능 | 레이블 필터 후 grep 방식 | 전문 검색 매우 빠름 |
| 운영 복잡성 | 낮음 | 높음 |
| 적합한 케이스 | Grafana 기반 모니터링, 비용 최적화 | 대규모 로그 분석, 전문 검색 필요 시 |

<br />

## 설치 및 실행

### Docker Compose (Loki + Promtail + Grafana)

```yaml
# docker-compose.yml
version: '3.8'
services:
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml

  promtail:
    image: grafana/promtail:latest
    volumes:
      - /var/log:/var/log
      - ./promtail-config.yml:/etc/promtail/config.yml
    command: -config.file=/etc/promtail/config.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    depends_on:
      - loki
```

<br />

## LogQL 기본 예시

```logql
# 특정 레이블의 로그 조회
{job="nginx"}

# 로그 내용 필터링
{job="nginx"} |= "error"

# 정규식 필터링
{job="nginx"} |~ "status=[45]\\d{2}"

# 5분간 에러 로그 발생률
rate({job="nginx"} |= "error" [5m])

# JSON 로그 파싱 후 필터
{job="app"} | json | level="error" | status >= 500
```
