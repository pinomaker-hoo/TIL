# Go (Golang)

## 개요

Go 언어에 대해 학습합니다. Google에서 만든 정적 타입, 컴파일 언어인 Go의 기본 문법부터 동시성 프로그래밍, 서버 구축, 배포까지 정리합니다.

<br />

## 목차

- [Go 기초 - 변수, 타입, 함수, 제어문 등 기본 문법](./basics.md)
- [구조체와 인터페이스 - Go의 타입 시스템](./structs-interfaces.md)
- [에러 처리 - Go의 에러 처리 패턴](./error-handling.md)
- [동시성 프로그래밍 - Goroutine과 Channel](./concurrency.md)
- [모듈과 패키지 - Go Modules와 패키지 관리](./modules-packages.md)
- [웹 서버 구축 - net/http, Gin, Echo, Fiber, GORM](./web-server.md)
- [배포 - Docker, Kubernetes, CI/CD, 클라우드 배포](./deployment.md)
- [EC2 배포 가이드 - systemd, Nginx, CodeDeploy](./deploy-ec2.md)
- [ECS 배포 가이드 - ECR, Fargate, Task Definition, Auto Scaling](./deploy-ecs.md)

<br />

---

## Go란?

### 정의

Go(Golang)는 **2009년 Google**에서 Robert Griesemer, Rob Pike, Ken Thompson이 만든 오픈 소스 프로그래밍 언어이다. C의 성능과 Python의 생산성을 결합하는 것을 목표로 설계되었다.

### 특징

- **간결한 문법** - 키워드가 25개뿐인 단순한 언어 설계
- **정적 타입 + 타입 추론** - 컴파일 시 타입 검사, `:=`로 타입 추론
- **빠른 컴파일** - 대규모 프로젝트도 몇 초 만에 컴파일
- **내장 동시성** - Goroutine과 Channel로 동시성 프로그래밍 지원
- **가비지 컬렉션** - 자동 메모리 관리
- **단일 바이너리 배포** - 의존성 없이 실행 가능한 바이너리 생성
- **크로스 컴파일** - 다양한 OS/아키텍처용 빌드 지원

### Go가 사용되는 곳

| 분야 | 대표 프로젝트 |
|------|--------------|
| 컨테이너/오케스트레이션 | Docker, Kubernetes, containerd |
| 클라우드 인프라 | Terraform, Prometheus, Grafana |
| 웹 서버/API | Gin, Echo, Fiber |
| 데이터베이스 | CockroachDB, InfluxDB, etcd |
| DevOps 도구 | Hugo, Vault, Consul |
