# Dashboard

## 개요

모니터링, 대시보드, 관측성(Observability) 도구에 대해 학습합니다. 현대 분산 시스템에서는 메트릭 수집, 로그 분석, 분산 추적(Tracing)을 통해 시스템의 상태를 파악하고 장애에 신속히 대응하는 것이 중요하다. 이러한 관측성의 세 가지 축(Three Pillars of Observability)을 중심으로 주요 오픈소스 및 상용 도구를 정리한다.

<br />

## 목차

### 메트릭 모니터링 (Metrics)

- [Prometheus - 오픈소스 메트릭 수집 및 모니터링 시스템](./prometheus.md)
- [Grafana - 오픈소스 데이터 시각화 및 대시보드 플랫폼](./grafana.md)
- [Datadog - 클라우드 기반 통합 모니터링 플랫폼](./datadog.md)

### 로그 수집/분석 (Logs)

- [ELK Stack - Elasticsearch + Logstash + Kibana 로그 분석 플랫폼](./elk.md)
- [Loki - Grafana 기반 경량 로그 수집 시스템](./loki.md)

### 분산 추적 (Tracing)

- [Jaeger - 오픈소스 분산 추적 시스템](./jaeger.md)

### 에러 모니터링 (Error Tracking)

- [Sentry - 실시간 에러 모니터링 및 성능 추적 플랫폼](./sentry.md)

<br />

## 오픈소스 대시보드/모니터링 도구 리스트

| 도구 | 분류 | 라이선스 | 개발사/커뮤니티 | 주요 특징 |
|------|------|----------|----------------|-----------|
| **Prometheus** | 메트릭 수집 | Apache 2.0 | CNCF | Pull 기반 메트릭 수집, PromQL 쿼리 언어, 알림 지원 |
| **Grafana** | 시각화/대시보드 | AGPL 3.0 | Grafana Labs | 다중 데이터소스 지원, 풍부한 플러그인, 알림 |
| **Loki** | 로그 수집 | AGPL 3.0 | Grafana Labs | 레이블 기반 로그 인덱싱, Grafana 통합, 경량 |
| **ELK Stack** | 로그 분석 | Elastic License / SSPL | Elastic | 전문 검색, 실시간 분석, Kibana 시각화 |
| **Jaeger** | 분산 추적 | Apache 2.0 | CNCF / Uber | OpenTelemetry 호환, 서비스 의존성 분석 |
| **Sentry** | 에러 모니터링 | BSL 1.1 | Sentry | 실시간 에러 추적, 성능 모니터링, 다양한 SDK |
| **Datadog** | 통합 모니터링 | 상용 (SaaS) | Datadog | 메트릭+로그+추적 통합, 500+ 인테그레이션, AI 기반 알림 |
| **Zabbix** | 인프라 모니터링 | GPL 2.0 | Zabbix LLC | 에이전트 기반, 네트워크/서버 모니터링, 자동 발견 |
| **Nagios** | 인프라 모니터링 | GPL 2.0 | Nagios | 플러그인 아키텍처, 호스트/서비스 모니터링 |
| **Thanos** | 메트릭 저장 | Apache 2.0 | CNCF | Prometheus 장기 저장소, 고가용성, 글로벌 쿼리 |
| **Mimir** | 메트릭 저장 | AGPL 3.0 | Grafana Labs | Prometheus 호환 장기 저장소, 수평 확장 |
| **Tempo** | 분산 추적 | AGPL 3.0 | Grafana Labs | 오브젝트 스토리지 기반, Grafana 통합 |
| **OpenTelemetry** | 관측성 프레임워크 | Apache 2.0 | CNCF | 벤더 중립 계측 표준, 메트릭+로그+추적 통합 |
| **Uptime Kuma** | 업타임 모니터링 | MIT | 커뮤니티 | 경량 셀프호스팅, HTTP/TCP/Ping 모니터링 |
| **Netdata** | 실시간 모니터링 | GPL 3.0 | Netdata | 제로 설정, 초당 수집, 경량 에이전트 |

<br />

## 관측성(Observability) 3축

```
┌─────────────────────────────────────────────┐
│              Observability                   │
│                                             │
│   ┌───────────┐ ┌──────────┐ ┌───────────┐ │
│   │  Metrics  │ │   Logs   │ │  Traces   │ │
│   │           │ │          │ │           │ │
│   │Prometheus │ │ ELK/Loki │ │  Jaeger   │ │
│   │ Grafana   │ │          │ │  Tempo    │ │
│   │ Datadog   │ │          │ │           │ │
│   └───────────┘ └──────────┘ └───────────┘ │
│                                             │
│         ┌──────────────────────┐            │
│         │   OpenTelemetry      │            │
│         │  (통합 계측 표준)      │            │
│         └──────────────────────┘            │
└─────────────────────────────────────────────┘
```

<br />

## 선택 가이드

| 기준 | Prometheus + Grafana | ELK Stack | Loki + Grafana | Datadog | Jaeger | Sentry |
|------|---------------------|-----------|----------------|---------|--------|--------|
| 주요 기능 | 메트릭 수집/시각화 | 로그 수집/분석 | 로그 수집/시각화 | 통합 모니터링 | 분산 추적 | 에러 추적 |
| 비용 | 무료 (오픈소스) | 무료 (오픈소스) | 무료 (오픈소스) | 유료 (SaaS) | 무료 (오픈소스) | 무료 + 유료 |
| 운영 난이도 | 중간 | 높음 | 낮음 | 매우 낮음 (SaaS) | 중간 | 낮음 |
| 리소스 사용량 | 낮음 | 높음 | 매우 낮음 | N/A (SaaS) | 중간 | 낮음 |
| 확장성 | Thanos/Mimir 연계 | 클러스터 확장 | 수평 확장 | 자동 확장 | 수평 확장 | 자동 확장 |
| Kubernetes 지원 | 우수 | 우수 | 우수 | 우수 | 우수 | 우수 |
| 적합한 케이스 | 인프라/앱 메트릭 | 대규모 로그 분석 | 경량 로그 수집 | 올인원 솔루션 | MSA 추적 | 앱 에러 관리 |
