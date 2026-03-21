# Datadog

## 개요

Datadog는 클라우드 기반 통합 모니터링 및 관측성(Observability) SaaS 플랫폼이다. 메트릭, 로그, 분산 추적(APM), 실시간 유저 모니터링(RUM), 보안 모니터링 등을 하나의 플랫폼에서 통합 제공한다. 500개 이상의 인테그레이션을 지원하며, AWS, GCP, Azure 등 주요 클라우드 환경과 네이티브로 연동된다.

<br />

## 주요 특징

- **통합 관측성** - 메트릭 + 로그 + APM(추적) + RUM을 하나의 플랫폼에서 제공
- **500+ 인테그레이션** - AWS, Kubernetes, Docker, Nginx, PostgreSQL 등 광범위한 연동
- **AI 기반 알림** - 이상 탐지(Anomaly Detection), 예측(Forecast), 아웃라이어(Outlier) 감지
- **APM (Application Performance Monitoring)** - 분산 추적, 서비스 맵, 프로파일링
- **Infrastructure Map** - 호스트, 컨테이너, 서비스의 실시간 토폴로지 시각화
- **SLO/SLI 관리** - Service Level Objective 추적 및 에러 버짓 관리
- **보안 모니터링** - Cloud SIEM, CSPM, Workload Security

<br />

## 아키텍처

```
┌──────────────────────────────────────────────────┐
│                  Datadog Platform                  │
│                                                    │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────┐ │
│  │ Metrics  │ │   Logs   │ │   APM    │ │ RUM  │ │
│  │          │ │          │ │ (Traces) │ │      │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └──┬───┘ │
│       └────────────┼────────────┼───────────┘     │
│                    ▼                               │
│         ┌────────────────────┐                    │
│         │   Unified Platform │                    │
│         │  (상관관계 분석)     │                    │
│         └────────────────────┘                    │
└──────────────────────────────────────────────────┘
                    ▲
                    │
        ┌───────────┼───────────┐
        │           │           │
  ┌─────┴─────┐ ┌──┴──────┐ ┌─┴────────┐
  │  Datadog  │ │ Datadog │ │ Datadog  │
  │  Agent    │ │ SDK/Lib │ │ Browser  │
  │ (Host)    │ │ (APM)   │ │ SDK(RUM) │
  └───────────┘ └─────────┘ └──────────┘
```

<br />

## 주요 제품군

| 제품 | 설명 |
|------|------|
| **Infrastructure Monitoring** | 호스트, 컨테이너, 프로세스 메트릭 모니터링 |
| **APM & Distributed Tracing** | 분산 추적, 서비스 맵, 코드 프로파일링 |
| **Log Management** | 로그 수집, 파싱, 검색, 분석 |
| **RUM (Real User Monitoring)** | 프론트엔드 성능 및 사용자 경험 모니터링 |
| **Synthetics** | 합성 모니터링 (API, 브라우저 테스트) |
| **Cloud SIEM** | 보안 이벤트 탐지 및 분석 |
| **CI Visibility** | CI/CD 파이프라인 모니터링 |

<br />

## 설치 및 실행

### Datadog Agent (Docker)

```yaml
# docker-compose.yml
version: '3.8'
services:
  datadog-agent:
    image: gcr.io/datadoghq/agent:latest
    container_name: datadog-agent
    environment:
      - DD_API_KEY=<YOUR_DATADOG_API_KEY>
      - DD_SITE=datadoghq.com
      - DD_APM_ENABLED=true
      - DD_LOGS_ENABLED=true
      - DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /proc/:/host/proc/:ro
      - /sys/fs/cgroup/:/host/sys/fs/cgroup:ro
    ports:
      - "8126:8126"  # APM
      - "8125:8125"  # DogStatsD
```

### Kubernetes에서 Helm 설치

```bash
helm repo add datadog https://helm.datadoghq.com
helm install datadog-agent datadog/datadog \
  --set datadog.apiKey=<YOUR_API_KEY> \
  --set datadog.apm.enabled=true \
  --set datadog.logs.enabled=true
```

<br />

## Datadog vs 오픈소스 스택 비교

| 비교 항목 | Datadog | Prometheus + Grafana + Loki |
|-----------|---------|----------------------------|
| 비용 | 호스트/로그 볼륨 기반 과금 | 무료 (인프라 비용만) |
| 운영 부담 | 없음 (SaaS) | 직접 운영 필요 |
| 기능 범위 | 메트릭+로그+APM+RUM+보안 | 메트릭+로그 (APM은 별도) |
| 확장성 | 자동 | 직접 구성 |
| 데이터 보관 | 플랜별 보관 기간 | 제한 없음 (직접 관리) |
| 적합한 케이스 | 빠른 도입, 올인원, 대규모 조직 | 비용 최적화, 커스터마이징 필요 시 |
