# Grafana

## 개요

Grafana는 Grafana Labs에서 개발한 오픈소스 데이터 시각화 및 대시보드 플랫폼이다. Prometheus, Elasticsearch, Loki, InfluxDB, MySQL, PostgreSQL 등 다양한 데이터소스를 연결하여 통합 대시보드를 구성할 수 있으며, 풍부한 시각화 패널과 알림 기능을 제공한다.

<br />

## 주요 특징

- **다중 데이터소스 지원** - 50개 이상의 데이터소스 플러그인 (Prometheus, Elasticsearch, Loki, CloudWatch 등)
- **풍부한 시각화** - 그래프, 테이블, 히트맵, 게이지 등 다양한 패널 타입
- **대시보드 템플릿** - 변수(Variables)를 활용한 동적 대시보드 구성
- **알림(Alerting)** - 조건 기반 알림 규칙 및 다양한 알림 채널 (Slack, Email, PagerDuty 등)
- **플러그인 생태계** - 커뮤니티 플러그인으로 기능 확장 가능
- **RBAC** - 팀/사용자별 역할 기반 접근 제어

<br />

## 아키텍처

```
┌──────────────────────────────────────────┐
│               Grafana Server              │
│                                          │
│  ┌──────────┐  ┌───────────┐  ┌───────┐ │
│  │Dashboard │  │  Alerting │  │ Users │ │
│  │ Engine   │  │  Engine   │  │ /Auth │ │
│  └────┬─────┘  └─────┬─────┘  └───────┘ │
│       │              │                    │
│  ┌────┴──────────────┴────┐              │
│  │    Data Source Proxy    │              │
│  └────┬───┬───┬───┬───┬──┘              │
└───────┼───┼───┼───┼───┼──────────────────┘
        │   │   │   │   │
        ▼   ▼   ▼   ▼   ▼
      Pro  Loki  ES  SQL Cloud
      meth       K       Watch
      eus
```

<br />

## Grafana 스택 (LGTM Stack)

Grafana Labs는 관측성의 세 축을 커버하는 통합 스택을 제공한다:

| 구성 요소 | 역할 | 설명 |
|-----------|------|------|
| **Loki** | Logs | 로그 수집 및 쿼리 |
| **Grafana** | Visualization | 통합 대시보드 및 시각화 |
| **Tempo** | Traces | 분산 추적 데이터 저장 |
| **Mimir** | Metrics | Prometheus 호환 장기 메트릭 저장 |

<br />

## 설치 및 실행

### Docker로 실행

```yaml
# docker-compose.yml
version: '3.8'
services:
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana

volumes:
  grafana_data:
```

### Prometheus + Grafana 통합 구성

```yaml
# docker-compose.yml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    depends_on:
      - prometheus
```

Grafana 접속 후 Data Source에서 Prometheus URL을 `http://prometheus:9090`으로 설정하면 연동이 완료된다.
