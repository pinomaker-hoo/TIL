# AWS ECS (Elastic Container Service)

## ECS란 무엇인가?

AWS ECS(Elastic Container Service)는 AWS에서 제공하는 완전 관리형 컨테이너 오케스트레이션 서비스입니다. Docker 컨테이너를 쉽게 실행, 중지 및 관리할 수 있게 해주는 서비스로, 클러스터 관리 인프라를 프로비저닝하고 유지할 필요 없이 컨테이너화된 애플리케이션을 손쉽게 배포할 수 있습니다.

## ECS의 주요 구성 요소

### 1. 클러스터 (Cluster)
- ECS 컨테이너를 실행하기 위한 논리적 그룹
- EC2 인스턴스 또는 Fargate를 통해 리소스 제공
- 여러 가용 영역에 걸쳐 확장 가능

### 2. 작업 정의 (Task Definition)
- 애플리케이션을 구성하는 컨테이너 집합을 정의하는 JSON 파일
- 컨테이너 이미지, CPU/메모리 할당, 포트 매핑, 환경 변수 등을 지정
- Docker 이미지, 볼륨, 네트워킹 설정 포함

### 3. 작업 (Task)
- 작업 정의를 기반으로 실행되는 컨테이너 인스턴스
- 클러스터 내에서 실행되는 작업 정의의 인스턴스
- 일회성 또는 배치 작업에 적합

### 4. 서비스 (Service)
- 지정된 수의 작업을 유지하고 관리
- 작업이 실패하면 자동으로 새 작업을 시작
- 로드 밸런서와 통합하여 트래픽 분산 가능

## ECS의 시작 유형 (Launch Types)

### 1. EC2 시작 유형
- 사용자가 관리하는 EC2 인스턴스에서 컨테이너 실행
- 인프라 관리에 대한 더 많은 제어 가능
- 비용 최적화를 위한 예약 인스턴스 활용 가능

### 2. Fargate 시작 유형
- 서버리스 컴퓨팅 엔진으로 인프라 관리 불필요
- 컨테이너에 필요한 CPU와 메모리만 지정
- 인프라 관리 오버헤드 없이 컨테이너에만 집중 가능

## ECS의 장점

1. **확장성**: 수요에 따라 컨테이너를 쉽게 확장하고 축소할 수 있음
2. **통합성**: AWS의 다른 서비스(로드 밸런서, IAM, CloudWatch 등)와 원활하게 통합
3. **유연성**: EC2와 Fargate 중 선택하여 비용과 제어 사이의 균형 조정 가능
4. **관리 용이성**: 컨테이너 배포, 업데이트, 모니터링을 위한 통합 관리 인터페이스 제공
5. **안정성**: 자동 복구 기능으로 실패한 컨테이너를 자동으로 교체

## ECS vs Kubernetes (EKS)

| 특성 | ECS | EKS (Kubernetes) |
|------|-----|-----------------|
| 복잡성 | 낮음 (AWS 특화) | 높음 (더 많은 기능) |
| 학습 곡선 | 완만함 | 가파름 |
| 유연성 | AWS 환경에 최적화 | 다양한 환경에서 실행 가능 |
| 관리 오버헤드 | 낮음 | 높음 |
| 커뮤니티 | AWS 중심 | 대규모 오픈소스 커뮤니티 |

## ECS 시작하기

### 1. 클러스터 생성
```bash
aws ecs create-cluster --cluster-name my-cluster
```

### 2. 작업 정의 등록
```json
{
  "family": "sample-app",
  "containerDefinitions": [
    {
      "name": "sample-app",
      "image": "nginx:latest",
      "cpu": 256,
      "memory": 512,
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ]
    }
  ],
  "requiresCompatibilities": ["FARGATE"],
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512"
}
```

### 3. 서비스 생성
```bash
aws ecs create-service \
  --cluster my-cluster \
  --service-name my-service \
  --task-definition sample-app \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345678],securityGroups=[sg-12345678],assignPublicIp=ENABLED}"
```

## ECS 모니터링

- **CloudWatch**: 컨테이너 메트릭 및 로그 모니터링
- **AWS X-Ray**: 분산 추적을 통한 성능 분석
- **Container Insights**: 컨테이너 수준의 상세 메트릭 수집

## 실제 사용 사례

1. **마이크로서비스 아키텍처**: 각 서비스를 독립적으로 배포 및 확장
2. **배치 처리**: 일회성 또는 예약된 작업 실행
3. **CI/CD 파이프라인**: 지속적 통합 및 배포 자동화
4. **웹 애플리케이션**: 고가용성 웹 서비스 호스팅

## 비용 최적화 팁

1. Fargate Spot 인스턴스 활용
2. 적절한 CPU 및 메모리 할당
3. 오토 스케일링 구성
4. 예약 인스턴스 사용 (EC2 시작 유형)
5. 컨테이너 이미지 최적화

## 결론

AWS ECS는 컨테이너화된 애플리케이션을 쉽게 배포하고 관리할 수 있는 강력한 서비스입니다. 특히 AWS 생태계 내에서 다른 서비스와의 통합이 원활하며, Fargate를 통해 서버리스 컨테이너 실행이 가능합니다. 복잡한 인프라 관리 없이 컨테이너의 이점을 누리고자 하는 조직에 이상적인 선택입니다.
