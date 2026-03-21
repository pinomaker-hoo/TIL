# ELK Stack

## 개요

ELK Stack은 Elastic사에서 개발한 로그 수집, 저장, 분석, 시각화를 위한 통합 플랫폼이다. **Elasticsearch**(검색/분석 엔진), **Logstash**(로그 수집/변환 파이프라인), **Kibana**(시각화/대시보드)의 세 가지 오픈소스 프로젝트로 구성되며, 최근에는 Beats(경량 데이터 수집기)가 추가되어 **Elastic Stack**이라고도 불린다.

<br />

## 주요 특징

- **전문 검색(Full-text Search)** - Elasticsearch의 역인덱스 기반 고속 전문 검색
- **실시간 로그 분석** - 대량의 로그 데이터를 실시간으로 수집, 파싱, 분석
- **풍부한 시각화** - Kibana를 통한 대시보드, 차트, 맵 등 다양한 시각화
- **확장성** - Elasticsearch 클러스터의 수평 확장으로 대규모 데이터 처리
- **Beats 에코시스템** - Filebeat, Metricbeat, Packetbeat 등 용도별 경량 수집기
- **Machine Learning** - 이상 탐지, 예측 분석 기능 (유료)

<br />

## 아키텍처

```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Filebeat │  │Metricbeat│  │Packetbeat│
│ (로그)    │  │ (메트릭)  │  │ (네트워크)│
└────┬─────┘  └────┬─────┘  └────┬─────┘
     │             │             │
     └─────────────┼─────────────┘
                   ▼
            ┌──────────────┐
            │   Logstash   │
            │  (수집/변환)  │
            │              │
            │ Input → Filter│
            │    → Output  │
            └──────┬───────┘
                   ▼
         ┌──────────────────┐
         │  Elasticsearch   │
         │  (저장/검색/분석) │
         │                  │
         │ ┌──────────────┐ │
         │ │   Index      │ │
         │ │   Shards     │ │
         │ └──────────────┘ │
         └────────┬─────────┘
                  ▼
           ┌──────────────┐
           │    Kibana    │
           │  (시각화/UI) │
           └──────────────┘
```

<br />

## 각 구성 요소

### Elasticsearch

분산형 RESTful 검색 및 분석 엔진으로 Apache Lucene 기반이다. JSON 문서를 저장하고 역인덱스를 사용하여 빠른 전문 검색을 제공한다.

### Logstash

서버 사이드 데이터 처리 파이프라인으로, 다양한 소스에서 데이터를 수집하고 변환하여 Elasticsearch로 전송한다. Input, Filter, Output 플러그인 구조를 가진다.

### Kibana

Elasticsearch 데이터를 시각화하는 웹 인터페이스다. 대시보드, 차트, 맵, 타임라인 등 다양한 시각화 도구를 제공하며 KQL(Kibana Query Language)로 데이터를 검색한다.

### Beats

경량 데이터 수집기(Shipper)로, 서버에 설치하여 Logstash 또는 Elasticsearch로 데이터를 직접 전송한다.

| Beat | 용도 |
|------|------|
| **Filebeat** | 로그 파일 수집 |
| **Metricbeat** | 시스템/서비스 메트릭 수집 |
| **Packetbeat** | 네트워크 패킷 데이터 수집 |
| **Heartbeat** | 업타임 모니터링 |
| **Auditbeat** | 감사 데이터 수집 |

<br />

## 설치 및 실행

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.12.0
    container_name: elasticsearch
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ports:
      - "9200:9200"
    volumes:
      - es_data:/usr/share/elasticsearch/data

  logstash:
    image: docker.elastic.co/logstash/logstash:8.12.0
    container_name: logstash
    ports:
      - "5044:5044"
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch

  kibana:
    image: docker.elastic.co/kibana/kibana:8.12.0
    container_name: kibana
    ports:
      - "5601:5601"
    environment:
      - ELASTICSEARCH_HOSTS=http://elasticsearch:9200
    depends_on:
      - elasticsearch

volumes:
  es_data:
```

### Logstash 설정 예시

```conf
# logstash.conf
input {
  beats {
    port => 5044
  }
}

filter {
  grok {
    match => { "message" => "%{COMBINEDAPACHELOG}" }
  }
  date {
    match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
  }
}

output {
  elasticsearch {
    hosts => ["http://elasticsearch:9200"]
    index => "logs-%{+YYYY.MM.dd}"
  }
}
```
