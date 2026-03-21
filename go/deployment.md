# Go 배포

> Go 애플리케이션을 빌드하고 Docker, Kubernetes, CI/CD 등을 활용하여 프로덕션 환경에 배포하는 방법을 정리한다.

## 목차

1. [바이너리 빌드](#1-바이너리-빌드)
2. [Docker 배포](#2-docker-배포)
3. [환경 설정 관리](#3-환경-설정-관리)
4. [헬스 체크와 모니터링](#4-헬스-체크와-모니터링)
5. [Kubernetes 배포](#5-kubernetes-배포)
6. [CI/CD 파이프라인](#6-cicd-파이프라인)
7. [클라우드 배포](#7-클라우드-배포)
8. [Makefile 활용](#8-makefile-활용)
9. [핵심 요약](#9-핵심-요약)

---

## 1. 바이너리 빌드

Go의 가장 큰 장점 중 하나는 **의존성 없는 단일 바이너리**로 컴파일된다는 것이다.

### 기본 빌드

```bash
# 기본 빌드
go build -o myapp ./cmd/api

# 실행
./myapp
```

### 프로덕션 빌드 (최적화)

```bash
# CGO 비활성화 + 정적 링킹 (어디서든 실행 가능한 바이너리)
CGO_ENABLED=0 go build -o myapp \
  -ldflags="-s -w" \
  ./cmd/api
```

| 플래그 | 설명 |
|--------|------|
| `CGO_ENABLED=0` | C 라이브러리 의존성 제거 (순수 Go 바이너리) |
| `-ldflags="-s -w"` | 디버그 심볼 제거 (바이너리 크기 30~40% 감소) |

### 크로스 컴파일

```bash
# Linux AMD64 (서버/Docker용)
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o myapp-linux-amd64 ./cmd/api

# Linux ARM64 (AWS Graviton 등)
GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o myapp-linux-arm64 ./cmd/api

# macOS Apple Silicon
GOOS=darwin GOARCH=arm64 go build -o myapp-darwin-arm64 ./cmd/api

# Windows
GOOS=windows GOARCH=amd64 go build -o myapp.exe ./cmd/api
```

### 빌드 시 버전 정보 주입

```go
// main.go
package main

import "fmt"

var (
    version   = "dev"
    buildTime = "unknown"
    gitCommit = "unknown"
)

func main() {
    fmt.Printf("Version: %s, Build: %s, Commit: %s\n", version, buildTime, gitCommit)
    // 서버 시작...
}
```

```bash
# 빌드 시 변수 주입
go build -o myapp \
  -ldflags="-s -w \
    -X main.version=1.2.0 \
    -X main.buildTime=$(date -u +%Y-%m-%dT%H:%M:%SZ) \
    -X main.gitCommit=$(git rev-parse --short HEAD)" \
  ./cmd/api
```

---

## 2. Docker 배포

### 기본 Dockerfile

```dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app

# 의존성 먼저 다운로드 (캐시 활용)
COPY go.mod go.sum ./
RUN go mod download

# 소스 복사 및 빌드
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app/myapp ./cmd/api

# 최종 이미지 (경량)
FROM alpine:3.19

RUN apk --no-cache add ca-certificates tzdata

WORKDIR /app
COPY --from=builder /app/myapp .

EXPOSE 8080

CMD ["./myapp"]
```

### 멀티 스테이지 최적화 (scratch 사용)

**scratch**는 완전히 빈 이미지로, 바이너리 크기를 최소화한다.

```dockerfile
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-s -w" \
    -o /app/myapp ./cmd/api

# scratch = 빈 이미지 (최종 이미지 ~10MB 이하)
FROM scratch

# SSL 인증서 (HTTPS 요청 시 필요)
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 타임존 데이터
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

COPY --from=builder /app/myapp /myapp

EXPOSE 8080

ENTRYPOINT ["/myapp"]
```

### 이미지 크기 비교

| 베이스 이미지 | 최종 이미지 크기 |
|--------------|-----------------|
| `golang:1.22` | ~800MB |
| `golang:1.22-alpine` (빌드만) + `alpine:3.19` | ~15MB |
| `golang:1.22-alpine` (빌드만) + `scratch` | ~8MB |

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgres://postgres:secret@db:5432/myapp?sslmode=disable
      - PORT=8080
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: secret
      POSTGRES_DB: myapp
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

```bash
# 실행
docker compose up -d

# 빌드 후 실행
docker compose up --build -d
```

---

## 3. 환경 설정 관리

### 환경 변수 기반 설정

```go
// internal/config/config.go
package config

import (
    "fmt"
    "os"
    "strconv"
)

type Config struct {
    Port        int
    DatabaseURL string
    JWTSecret   string
    Environment string // development, staging, production
    LogLevel    string
}

func Load() (*Config, error) {
    port, err := strconv.Atoi(getEnv("PORT", "8080"))
    if err != nil {
        return nil, fmt.Errorf("PORT 파싱 실패: %w", err)
    }

    dbURL := os.Getenv("DATABASE_URL")
    if dbURL == "" {
        return nil, fmt.Errorf("DATABASE_URL 환경 변수가 필요합니다")
    }

    return &Config{
        Port:        port,
        DatabaseURL: dbURL,
        JWTSecret:   getEnv("JWT_SECRET", "dev-secret"),
        Environment: getEnv("ENVIRONMENT", "development"),
        LogLevel:    getEnv("LOG_LEVEL", "info"),
    }, nil
}

func getEnv(key, fallback string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return fallback
}
```

### .env 파일 사용 (개발 환경)

```bash
go get github.com/joho/godotenv
```

```env
# .env
PORT=8080
DATABASE_URL=postgres://postgres:secret@localhost:5432/myapp?sslmode=disable
JWT_SECRET=my-secret-key
ENVIRONMENT=development
```

```go
import "github.com/joho/godotenv"

func main() {
    // .env 파일 로드 (없어도 에러 아님)
    godotenv.Load()

    cfg, err := config.Load()
    if err != nil {
        log.Fatal(err)
    }
    // ...
}
```

---

## 4. 헬스 체크와 모니터링

### 헬스 체크 엔드포인트

```go
// 기본 헬스 체크
r.GET("/health", func(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{"status": "ok"})
})

// 상세 헬스 체크 (DB, Redis 등 확인)
r.GET("/health/ready", func(c *gin.Context) {
    // DB 연결 확인
    sqlDB, err := db.DB()
    if err != nil || sqlDB.Ping() != nil {
        c.JSON(http.StatusServiceUnavailable, gin.H{
            "status":   "unhealthy",
            "database": "disconnected",
        })
        return
    }

    c.JSON(http.StatusOK, gin.H{
        "status":   "healthy",
        "database": "connected",
    })
})
```

### Prometheus 메트릭

```bash
go get github.com/prometheus/client_golang
```

```go
import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total number of HTTP requests",
        },
        []string{"method", "path", "status"},
    )

    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(httpRequestDuration)
}

func main() {
    r := gin.Default()

    // /metrics 엔드포인트
    r.GET("/metrics", gin.WrapH(promhttp.Handler()))

    r.Run(":8080")
}
```

---

## 5. Kubernetes 배포

### Deployment + Service

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-api
  labels:
    app: myapp-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp-api
  template:
    metadata:
      labels:
        app: myapp-api
    spec:
      containers:
        - name: api
          image: myregistry/myapp-api:1.0.0
          ports:
            - containerPort: 8080
          env:
            - name: PORT
              value: "8080"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: myapp-secrets
                  key: database-url
            - name: ENVIRONMENT
              value: "production"
          resources:
            requests:
              cpu: "100m"
              memory: "64Mi"
            limits:
              cpu: "500m"
              memory: "128Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-api
spec:
  selector:
    app: myapp-api
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

> Go 앱은 바이너리 크기가 작고 시작이 빠르므로 Kubernetes에서 **스케일 아웃이 매우 빠르다**. 메모리 사용량도 적어 리소스 효율이 높다.

---

## 6. CI/CD 파이프라인

### GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: 의존성 다운로드
        run: go mod download

      - name: 린트
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest

      - name: 테스트
        run: go test -race -coverprofile=coverage.out ./...

      - name: 빌드 확인
        run: CGO_ENABLED=0 go build -o /dev/null ./cmd/api

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Docker 로그인
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker 빌드 & 푸시
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:latest
            ghcr.io/${{ github.repository }}:${{ github.sha }}
```

---

## 7. 클라우드 배포

### AWS ECS (Fargate)

```bash
# Docker 이미지를 ECR에 푸시
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.ap-northeast-2.amazonaws.com

docker build -t myapp-api .
docker tag myapp-api:latest 123456789.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-api:latest
docker push 123456789.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-api:latest
```

### AWS Lambda (서버리스)

```bash
go get github.com/aws/aws-lambda-go
```

```go
package main

import (
    "context"
    "github.com/aws/aws-lambda-go/events"
    "github.com/aws/aws-lambda-go/lambda"
)

func handler(ctx context.Context, request events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
    return events.APIGatewayProxyResponse{
        StatusCode: 200,
        Body:       `{"message": "Hello from Lambda"}`,
        Headers:    map[string]string{"Content-Type": "application/json"},
    }, nil
}

func main() {
    lambda.Start(handler)
}
```

```bash
# Lambda용 빌드
GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -o bootstrap ./cmd/lambda
zip function.zip bootstrap

# 배포
aws lambda create-function \
  --function-name myapp \
  --runtime provided.al2023 \
  --handler bootstrap \
  --zip-file fileb://function.zip \
  --role arn:aws:iam::123456789:role/lambda-role
```

### Google Cloud Run

```bash
# Cloud Run에 바로 배포 (Dockerfile 자동 빌드)
gcloud run deploy myapp-api \
  --source . \
  --region asia-northeast3 \
  --allow-unauthenticated
```

---

## 8. Makefile 활용

프로젝트의 빌드, 테스트, 배포 명령을 Makefile로 관리한다.

```makefile
# Makefile
APP_NAME = myapp
VERSION = $(shell git describe --tags --always --dirty)
BUILD_TIME = $(shell date -u +%Y-%m-%dT%H:%M:%SZ)
GIT_COMMIT = $(shell git rev-parse --short HEAD)
LDFLAGS = -s -w -X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME) -X main.gitCommit=$(GIT_COMMIT)

.PHONY: build run test lint clean docker-build docker-push

# 빌드
build:
	CGO_ENABLED=0 go build -ldflags="$(LDFLAGS)" -o bin/$(APP_NAME) ./cmd/api

# 개발 서버 실행
run:
	go run ./cmd/api

# 테스트
test:
	go test -race -cover ./...

# 린트
lint:
	golangci-lint run

# 정리
clean:
	rm -rf bin/

# Docker 빌드
docker-build:
	docker build -t $(APP_NAME):$(VERSION) .

# Docker 푸시
docker-push:
	docker tag $(APP_NAME):$(VERSION) ghcr.io/username/$(APP_NAME):$(VERSION)
	docker push ghcr.io/username/$(APP_NAME):$(VERSION)

# 마이그레이션
migrate-up:
	go run ./cmd/migrate up

migrate-down:
	go run ./cmd/migrate down
```

```bash
make build        # 프로덕션 빌드
make run          # 개발 서버 실행
make test         # 테스트 실행
make docker-build # Docker 이미지 빌드
```

---

## 9. 핵심 요약

- Go는 **CGO_ENABLED=0 + -ldflags="-s -w"**로 경량 정적 바이너리를 생성한다
- Docker **멀티 스테이지 빌드**로 최종 이미지를 ~8MB까지 줄일 수 있다 (scratch 사용)
- **환경 변수**로 설정을 관리하고, `.env` 파일은 개발 환경에서만 사용한다
- **/health**, **/health/ready** 엔드포인트로 헬스 체크를 구현하며, Prometheus 메트릭을 노출한다
- **Kubernetes**에서 Go 앱은 시작이 빠르고 메모리 사용량이 적어 스케일링에 유리하다
- **GitHub Actions**로 테스트 → 빌드 → Docker 푸시 CI/CD 파이프라인을 구성한다
- AWS ECS/Lambda, Google Cloud Run 등 다양한 클라우드에 배포할 수 있다
- **Makefile**로 빌드/테스트/배포 명령을 표준화한다

## 참고 자료

- [Docker - Go 공식 가이드](https://docs.docker.com/language/golang/)
- [Go - Building and Deploying](https://go.dev/doc/articles/race_detector)
- [Kubernetes - Go 앱 배포 예시](https://kubernetes.io/docs/tutorials/)
- [AWS Lambda - Go 런타임](https://docs.aws.amazon.com/lambda/latest/dg/lambda-golang.html)
- [Google Cloud Run 문서](https://cloud.google.com/run/docs)
