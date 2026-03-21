# Go ECS 배포 가이드

> AWS ECS(Elastic Container Service)를 사용하여 Go 애플리케이션을 컨테이너로 배포하는 방법을 정리한다. ECR 이미지 관리, Fargate/EC2 실행 타입, Task Definition, 서비스 구성, CI/CD 자동화까지 단계별로 다룬다.

## 목차

1. [ECS 배포 아키텍처](#1-ecs-배포-아키텍처)
2. [ECS 핵심 개념](#2-ecs-핵심-개념)
3. [ECR에 Docker 이미지 푸시](#3-ecr에-docker-이미지-푸시)
4. [Task Definition 작성](#4-task-definition-작성)
5. [ECS 클러스터와 서비스 생성](#5-ecs-클러스터와-서비스-생성)
6. [ALB 연동](#6-alb-연동)
7. [환경 변수와 시크릿 관리](#7-환경-변수와-시크릿-관리)
8. [CI/CD 자동 배포 (GitHub Actions)](#8-cicd-자동-배포-github-actions)
9. [Auto Scaling](#9-auto-scaling)
10. [로그와 모니터링](#10-로그와-모니터링)
11. [Fargate vs EC2 실행 타입](#11-fargate-vs-ec2-실행-타입)
12. [핵심 요약](#12-핵심-요약)

---

## 1. ECS 배포 아키텍처

```
                    ┌──────────────┐
                    │   Route 53   │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     ALB      │
                    │ (포트 80/443) │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │  ECS Cluster │
                    │              │
                    │ ┌──────────┐ │
                    │ │ Service  │ │
                    │ │          │ │
                    │ │ Task #1  │ │    ┌─────────┐
                    │ │ Task #2  │ ├───▶│   RDS   │
                    │ │ Task #3  │ │    └─────────┘
                    │ └──────────┘ │
                    └──────────────┘
                           ▲
                    ┌──────┴───────┐
                    │     ECR      │
                    │ (이미지 저장) │
                    └──────────────┘
```

### EC2 배포와의 차이

| 항목 | EC2 직접 배포 | ECS 배포 |
|------|--------------|----------|
| 서버 관리 | 직접 패치/보안 업데이트 | Fargate: 관리 불필요 |
| 배포 단위 | 바이너리 파일 | Docker 이미지 |
| 스케일링 | ASG 수동 구성 | ECS 서비스 Auto Scaling |
| 롤백 | 수동 | 이전 Task Definition으로 자동 |
| 로드밸런싱 | ALB + Target Group 수동 연결 | ECS 서비스가 자동 관리 |
| 환경 일관성 | OS별 차이 가능 | Docker로 완전 동일 |

---

## 2. ECS 핵심 개념

```
ECS Cluster (클러스터)
  └── Service (서비스) - 원하는 Task 수를 유지
        └── Task (태스크) - 실행 중인 컨테이너 인스턴스
              └── Container (컨테이너) - Docker 컨테이너
                    └── Task Definition (태스크 정의) - 설계도
```

| 개념 | 설명 |
|------|------|
| **Cluster** | ECS 리소스의 논리적 그룹 |
| **Task Definition** | 컨테이너 실행 설계도 (이미지, CPU, 메모리, 포트, 환경변수 등) |
| **Task** | Task Definition을 기반으로 실행된 컨테이너 인스턴스 |
| **Service** | 원하는 수의 Task를 유지하고 ALB와 연결 |
| **ECR** | Docker 이미지 저장소 (Docker Hub의 AWS 버전) |

### 실행 타입

- **Fargate** - 서버리스. 인프라 관리 불필요. 태스크 단위 과금
- **EC2** - EC2 인스턴스 위에서 컨테이너 실행. 인스턴스 관리 필요

---

## 3. ECR에 Docker 이미지 푸시

### ECR 리포지토리 생성

```bash
# ECR 리포지토리 생성
aws ecr create-repository \
  --repository-name myapp-api \
  --region ap-northeast-2 \
  --image-scanning-configuration scanOnPush=true
```

### Dockerfile (Go 최적화)

```dockerfile
# Dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o /app/myapp ./cmd/api

FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=builder /app/myapp /myapp

EXPOSE 8080

ENTRYPOINT ["/myapp"]
```

### 이미지 빌드 및 푸시

```bash
# 변수 설정
AWS_ACCOUNT_ID=123456789012
AWS_REGION=ap-northeast-2
ECR_REPO=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/myapp-api

# ECR 로그인
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# 빌드
docker build -t myapp-api .

# 태그
docker tag myapp-api:latest $ECR_REPO:latest
docker tag myapp-api:latest $ECR_REPO:$(git rev-parse --short HEAD)

# 푸시
docker push $ECR_REPO:latest
docker push $ECR_REPO:$(git rev-parse --short HEAD)
```

---

## 4. Task Definition 작성

### JSON 형식 (AWS CLI / Terraform용)

```json
{
  "family": "myapp-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "api",
      "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-api:latest",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        { "name": "PORT", "value": "8080" },
        { "name": "ENVIRONMENT", "value": "production" },
        { "name": "LOG_LEVEL", "value": "info" }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:ssm:ap-northeast-2:123456789012:parameter/myapp/production/DATABASE_URL"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:ssm:ap-northeast-2:123456789012:parameter/myapp/production/JWT_SECRET"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -q --spider http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 10
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/myapp-api",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

### Fargate CPU/메모리 조합

| CPU (vCPU) | 메모리 옵션 |
|-----------|------------|
| 0.25 (256) | 512MB, 1GB, 2GB |
| 0.5 (512) | 1GB ~ 4GB |
| 1 (1024) | 2GB ~ 8GB |
| 2 (2048) | 4GB ~ 16GB |
| 4 (4096) | 8GB ~ 30GB |

> Go 앱은 메모리 사용량이 적으므로 대부분 **256 CPU / 512MB 메모리**로 충분하다.

### Task Definition 등록

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json
```

---

## 5. ECS 클러스터와 서비스 생성

### 클러스터 생성

```bash
# Fargate 클러스터 생성
aws ecs create-cluster \
  --cluster-name myapp-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1 \
    capacityProvider=FARGATE_SPOT,weight=3
```

> **FARGATE_SPOT**은 Fargate 대비 최대 70% 저렴하지만 중단될 수 있다. Stateless API 서버에 적합하다.

### 서비스 생성

```bash
aws ecs create-service \
  --cluster myapp-cluster \
  --service-name myapp-api \
  --task-definition myapp-api \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration '{
    "awsvpcConfiguration": {
      "subnets": ["subnet-aaa", "subnet-bbb"],
      "securityGroups": ["sg-xxxxxxxx"],
      "assignPublicIp": "DISABLED"
    }
  }' \
  --load-balancers '[{
    "targetGroupArn": "arn:aws:elasticloadbalancing:...:targetgroup/myapp-tg/...",
    "containerName": "api",
    "containerPort": 8080
  }]' \
  --deployment-configuration '{
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    },
    "maximumPercent": 200,
    "minimumHealthyPercent": 100
  }' \
  --health-check-grace-period-seconds 30
```

### 배포 설정 설명

| 설정 | 값 | 설명 |
|------|-----|------|
| `maximumPercent` | 200 | 배포 중 최대 태스크 수 (원래의 200%) |
| `minimumHealthyPercent` | 100 | 배포 중 최소 정상 태스크 비율 |
| `deploymentCircuitBreaker` | enable + rollback | 배포 실패 시 자동 롤백 |
| `healthCheckGracePeriod` | 30s | ALB 헬스 체크 유예 시간 |

> `maximumPercent=200, minimumHealthyPercent=100`으로 설정하면 **롤링 배포**가 된다. 새 태스크가 정상 확인된 후 이전 태스크를 종료한다.

---

## 6. ALB 연동

### Target Group 생성

```bash
# Target Group (IP 타입 - Fargate용)
aws elbv2 create-target-group \
  --name myapp-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id vpc-xxxxxxxx \
  --target-type ip \
  --health-check-path /health \
  --health-check-interval-seconds 15 \
  --healthy-threshold-count 2 \
  --unhealthy-threshold-count 3
```

### ALB 생성 및 리스너 설정

```bash
# ALB 생성
aws elbv2 create-load-balancer \
  --name myapp-alb \
  --subnets subnet-aaa subnet-bbb \
  --security-groups sg-xxxxxxxx \
  --scheme internet-facing

# HTTPS 리스너 (ACM 인증서 사용)
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:...:loadbalancer/app/myapp-alb/... \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:...:certificate/... \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:...:targetgroup/myapp-tg/...

# HTTP → HTTPS 리다이렉트
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:...:loadbalancer/app/myapp-alb/... \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=redirect,RedirectConfig='{Protocol=HTTPS,Port=443,StatusCode=HTTP_301}'
```

---

## 7. 환경 변수와 시크릿 관리

### Task Definition에서의 관리 방식

```json
{
  "containerDefinitions": [
    {
      "name": "api",
      "environment": [
        { "name": "PORT", "value": "8080" },
        { "name": "ENVIRONMENT", "value": "production" }
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:ssm:ap-northeast-2:123456789012:parameter/myapp/prod/DATABASE_URL"
        },
        {
          "name": "JWT_SECRET",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:myapp/jwt-xxxxx"
        }
      ]
    }
  ]
}
```

| 저장소 | 용도 | secrets valueFrom 형식 |
|--------|------|----------------------|
| **환경 변수 (environment)** | 민감하지 않은 설정 | 직접 값 입력 |
| **SSM Parameter Store** | 일반 시크릿 | `arn:aws:ssm:...:parameter/path` |
| **Secrets Manager** | DB 비밀번호, API 키 등 | `arn:aws:secretsmanager:...:secret:name` |

### IAM 역할 설정

ECS 태스크가 SSM/Secrets Manager에 접근하려면 **Execution Role**에 권한이 필요하다.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters",
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:ssm:ap-northeast-2:123456789012:parameter/myapp/*",
        "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:myapp/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

---

## 8. CI/CD 자동 배포 (GitHub Actions)

### 전체 흐름

```
GitHub Push
    │
    ▼
GitHub Actions
    ├── go test
    ├── docker build
    ├── docker push → ECR
    └── aws ecs update-service → 새 Task Definition으로 롤링 배포
```

### GitHub Actions 워크플로우

```yaml
# .github/workflows/deploy-ecs.yml
name: Deploy to ECS

on:
  push:
    branches: [main]

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: myapp-api
  ECS_CLUSTER: myapp-cluster
  ECS_SERVICE: myapp-api
  CONTAINER_NAME: api

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'
      - run: go test -race ./...

  deploy:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: AWS 자격 증명
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: ECR 로그인
        id: ecr-login
        uses: aws-actions/amazon-ecr-login@v2

      - name: Docker 빌드 & 푸시
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.ecr-login.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Task Definition 업데이트
        id: task-def
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ env.CONTAINER_NAME }}
          image: ${{ steps.build-image.outputs.image }}

      - name: ECS 서비스 배포
        uses: aws-actions/amazon-ecs-deploy-task-definition@v2
        with:
          task-definition: ${{ steps.task-def.outputs.task-definition }}
          service: ${{ env.ECS_SERVICE }}
          cluster: ${{ env.ECS_CLUSTER }}
          wait-for-service-stability: true
```

### 배포 과정

```
1. 새 Docker 이미지 빌드 → ECR 푸시
2. Task Definition의 이미지 태그를 새 커밋 SHA로 업데이트
3. ECS 서비스 업데이트 → 새 Task Definition으로 롤링 배포
4. 새 태스크 시작 → ALB 헬스 체크 통과 → 트래픽 전환
5. 이전 태스크 종료
6. wait-for-service-stability로 배포 완료 확인
```

---

## 9. Auto Scaling

### Target Tracking Scaling

```bash
# Auto Scaling 등록
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-cluster/myapp-api \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# CPU 70% 기준 스케일링
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/myapp-cluster/myapp-api \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name myapp-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    },
    "ScaleInCooldown": 300,
    "ScaleOutCooldown": 60
  }'
```

### 요청 수 기준 스케일링

```bash
# ALB 요청 수 기준
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/myapp-cluster/myapp-api \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name myapp-request-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 1000.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ALBRequestCountPerTarget",
      "ResourceLabel": "app/myapp-alb/.../targetgroup/myapp-tg/..."
    },
    "ScaleInCooldown": 300,
    "ScaleOutCooldown": 60
  }'
```

---

## 10. 로그와 모니터링

### CloudWatch Logs

Task Definition에서 `awslogs` 드라이버를 설정하면 컨테이너 로그가 CloudWatch Logs로 자동 전송된다.

```bash
# 로그 그룹 생성
aws logs create-log-group \
  --log-group-name /ecs/myapp-api \
  --retention-in-days 30

# 로그 확인
aws logs tail /ecs/myapp-api --follow

# 특정 패턴 검색
aws logs filter-log-events \
  --log-group-name /ecs/myapp-api \
  --filter-pattern "ERROR" \
  --start-time $(date -d '1 hour ago' +%s000)
```

### Container Insights

```bash
# Container Insights 활성화
aws ecs update-cluster-settings \
  --cluster myapp-cluster \
  --settings name=containerInsights,value=enabled
```

Container Insights가 제공하는 메트릭:

- CPU/메모리 사용률 (클러스터, 서비스, 태스크 수준)
- 네트워크 I/O
- 스토리지 I/O
- 실행 중인 태스크 수

### CloudWatch 알람

```bash
# 서비스 CPU 80% 이상 알림
aws cloudwatch put-metric-alarm \
  --alarm-name "myapp-ecs-high-cpu" \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=myapp-cluster Name=ServiceName,Value=myapp-api \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:ap-northeast-2:123456789012:alerts

# 실행 중인 태스크 수 0 알림 (서비스 다운)
aws cloudwatch put-metric-alarm \
  --alarm-name "myapp-ecs-no-tasks" \
  --namespace AWS/ECS \
  --metric-name RunningTaskCount \
  --dimensions Name=ClusterName,Value=myapp-cluster Name=ServiceName,Value=myapp-api \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:ap-northeast-2:123456789012:alerts
```

---

## 11. Fargate vs EC2 실행 타입

| 항목 | Fargate | EC2 |
|------|---------|-----|
| **서버 관리** | 불필요 (서버리스) | EC2 인스턴스 관리 필요 |
| **과금** | 태스크의 CPU/메모리 사용량 | EC2 인스턴스 비용 |
| **스케일링** | 즉시 (새 태스크 시작) | 인스턴스 추가 필요 시 느림 |
| **비용 (낮은 부하)** | 저렴 (사용한 만큼) | 인스턴스 상시 비용 |
| **비용 (높은 부하)** | 비쌀 수 있음 | Reserved Instance로 절감 가능 |
| **GPU 지원** | ❌ | ✅ |
| **디스크 커스터마이징** | 제한적 (20GB ephemeral) | 자유롭게 설정 |
| **네트워크** | awsvpc 모드만 | bridge, host, awsvpc |
| **적합한 경우** | API 서버, 마이크로서비스 | GPU 워크로드, 대용량 디스크 |

### 비용 최적화 전략

```
Fargate:
  ├── FARGATE_SPOT (최대 70% 할인, 중단 가능)
  └── Savings Plans (1~3년 약정)

EC2 실행 타입:
  ├── Spot Instance (최대 90% 할인)
  ├── Reserved Instance (1~3년 약정)
  └── Graviton (ARM64) 인스턴스 (20% 저렴)
```

> **추천**: 대부분의 Go API 서버는 **Fargate**가 적합하다. 관리 비용이 없고, Go의 작은 메모리 풋프린트 덕분에 Fargate 비용도 저렴하다. 비용 최적화가 필요하면 **FARGATE_SPOT**을 혼합 사용한다.

---

## 12. 핵심 요약

- **ECR**에 Docker 이미지를 푸시하고, **Task Definition**으로 컨테이너 실행 환경을 정의한다
- **Fargate**를 사용하면 서버 관리 없이 컨테이너를 실행할 수 있다 (Go 앱에 권장)
- Go 앱은 **256 CPU / 512MB 메모리**로 충분하여 Fargate 비용이 저렴하다
- **SSM Parameter Store / Secrets Manager**로 시크릿을 Task Definition에 안전하게 주입한다
- **GitHub Actions**로 Push → 빌드 → ECR 푸시 → ECS 서비스 배포를 자동화한다
- **롤링 배포** (maximumPercent=200, minimumHealthyPercent=100)로 무중단 배포한다
- **배포 실패 시 Circuit Breaker**로 자동 롤백된다
- **Target Tracking Auto Scaling**으로 CPU/요청 수 기준으로 태스크를 자동 스케일링한다
- **CloudWatch Logs**로 컨테이너 로그를 수집하고, **Container Insights**로 메트릭을 모니터링한다

## 참고 자료

- [AWS ECS 사용 설명서](https://docs.aws.amazon.com/ecs/)
- [AWS ECS 베스트 프랙티스](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Amazon ECR 사용 설명서](https://docs.aws.amazon.com/ecr/)
- [AWS ECS GitHub Actions](https://github.com/aws-actions/amazon-ecs-deploy-task-definition)
- [Fargate 요금](https://aws.amazon.com/fargate/pricing/)
