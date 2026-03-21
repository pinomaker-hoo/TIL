# AWS ECS vs EKS 비교

## 목차

- [1. 개요](#1-개요)
- [2. ECS (Elastic Container Service)](#2-ecs-elastic-container-service)
- [3. EKS (Elastic Kubernetes Service)](#3-eks-elastic-kubernetes-service)
- [4. ECS vs EKS 핵심 비교](#4-ecs-vs-eks-핵심-비교)
- [5. 비용 비교](#5-비용-비교)
- [6. 선택 기준](#6-선택-기준)

<br />

## 1. 개요

<br />

AWS에서 컨테이너 기반 워크로드를 운영하기 위한 대표적인 오케스트레이션 서비스는 ECS와 EKS 두 가지다. 둘 다 컨테이너를 실행하고 관리하는 서비스이지만, 오케스트레이션 엔진과 운영 방식에서 근본적인 차이가 있다.

| 항목             | ECS                        | EKS                          |
| ---------------- | -------------------------- | ---------------------------- |
| 오케스트레이션   | AWS 자체 오케스트레이터    | Kubernetes (오픈소스)        |
| 출시 시기        | 2014년                     | 2018년                       |
| 관리 주체        | AWS 완전 관리              | Kubernetes Control Plane 관리 |
| 학습 난이도      | 낮음                       | 높음                         |

<br />

## 2. ECS (Elastic Container Service)

<br />

### (1) ECS란?

ECS는 AWS에서 자체 개발한 컨테이너 오케스트레이션 서비스다. Docker 컨테이너를 실행, 중지, 관리할 수 있으며 AWS 서비스와의 긴밀한 통합이 특징이다.

<br />

### (2) ECS의 핵심 개념

- **Cluster**: 컨테이너가 실행되는 논리적인 그룹
- **Task Definition**: 컨테이너의 실행 설정을 정의하는 JSON 템플릿 (이미지, CPU, 메모리, 포트, 환경변수 등)
- **Task**: Task Definition을 기반으로 실행되는 컨테이너 인스턴스
- **Service**: 지정된 수의 Task를 지속적으로 유지하고 관리하는 단위

<br />

### (3) ECS 시작 유형

ECS는 컨테이너를 실행하는 인프라에 따라 두 가지 시작 유형을 제공한다.

**EC2 시작 유형**

- 사용자가 EC2 인스턴스를 직접 프로비저닝하고 관리한다.
- EC2 인스턴스에 ECS Agent가 설치되어 클러스터에 등록된다.
- 인스턴스 유형, 수량, 스케일링을 직접 관리해야 한다.
- GPU 워크로드나 특수한 인스턴스 요구사항이 있을 때 유리하다.

**Fargate 시작 유형**

- 서버리스 컨테이너 실행 환경으로 인프라 관리가 불필요하다.
- Task 단위로 CPU와 메모리를 지정하면 AWS가 인프라를 자동 할당한다.
- 인프라 관리 부담이 없어 운영 효율성이 높다.
- EC2 시작 유형 대비 단위 비용이 높다.

<br />

### (4) ECS의 장점

1. **AWS 네이티브 통합**: IAM, CloudWatch, ALB, VPC 등 AWS 서비스와 긴밀하게 통합되어 별도의 설정 없이 사용 가능하다.
2. **낮은 학습 곡선**: Kubernetes에 비해 개념이 단순하여 빠르게 도입할 수 있다.
3. **Control Plane 비용 없음**: ECS 자체에는 추가 비용이 발생하지 않는다.
4. **운영 단순성**: AWS가 오케스트레이터를 완전히 관리하므로 Control Plane 운영 부담이 없다.

<br />

### (5) ECS의 단점

1. **AWS 종속(Vendor Lock-in)**: AWS 전용 서비스이므로 다른 클라우드나 온프레미스로의 마이그레이션이 어렵다.
2. **제한된 생태계**: Kubernetes에 비해 서드파티 도구와 플러그인이 제한적이다.
3. **커스터마이징 한계**: 오케스트레이션 로직을 세밀하게 제어하기 어렵다.

<br />

## 3. EKS (Elastic Kubernetes Service)

<br />

### (1) EKS란?

EKS는 AWS에서 제공하는 관리형 Kubernetes 서비스다. Kubernetes Control Plane(API Server, etcd, Scheduler, Controller Manager)을 AWS가 관리하며, 사용자는 워커 노드와 애플리케이션 배포에 집중할 수 있다.

<br />

### (2) EKS의 핵심 개념

- **Cluster**: Kubernetes Control Plane + 워커 노드로 구성
- **Node Group**: 워커 노드(EC2 인스턴스)의 그룹. Managed Node Group을 사용하면 노드의 프로비저닝과 업데이트를 AWS가 관리한다.
- **Pod**: Kubernetes에서 컨테이너를 실행하는 최소 단위
- **Deployment, Service, Ingress**: Kubernetes의 표준 리소스를 그대로 사용

<br />

### (3) EKS 워커 노드 유형

**Managed Node Group**

- AWS가 EC2 인스턴스의 프로비저닝과 수명 주기를 관리한다.
- AMI 업데이트, 드레이닝 등을 자동화할 수 있다.

**Self-Managed Node**

- 사용자가 EC2 인스턴스를 직접 프로비저닝하고 클러스터에 등록한다.
- 최대한의 커스터마이징이 가능하다.

**Fargate**

- ECS와 마찬가지로 서버리스로 Pod를 실행할 수 있다.
- DaemonSet을 사용할 수 없고, 일부 Kubernetes 기능에 제약이 있다.

<br />

### (4) EKS의 장점

1. **표준 Kubernetes**: 오픈소스 Kubernetes와 완전히 호환되어 멀티 클라우드 및 하이브리드 전략에 유리하다.
2. **풍부한 생태계**: Helm, Istio, ArgoCD, Prometheus 등 방대한 Kubernetes 생태계를 활용할 수 있다.
3. **이식성(Portability)**: 다른 클라우드(GKE, AKS)나 온프레미스 Kubernetes 환경으로 마이그레이션이 용이하다.
4. **세밀한 제어**: Kubernetes의 다양한 리소스와 컨트롤러를 활용하여 복잡한 배포 전략을 구현할 수 있다.
5. **커뮤니티**: 활발한 오픈소스 커뮤니티의 지원을 받을 수 있다.

<br />

### (5) EKS의 단점

1. **높은 학습 곡선**: Kubernetes 자체의 개념과 운영 지식이 필요하다.
2. **Control Plane 비용**: 클러스터당 시간당 비용이 발생한다.
3. **운영 복잡성**: 네트워킹(CNI), 스토리지(CSI), 모니터링, 로깅 등을 별도로 구성해야 한다.
4. **업그레이드 부담**: Kubernetes 버전 업그레이드 시 호환성 검증과 마이그레이션 작업이 필요하다.

<br />

## 4. ECS vs EKS 핵심 비교

<br />

### (1) 아키텍처 비교

```
[ECS 아키텍처]

ECS Cluster
├── Service A
│   ├── Task 1 (컨테이너)
│   └── Task 2 (컨테이너)
└── Service B
    ├── Task 1 (컨테이너)
    └── Task 2 (컨테이너)

→ Task Definition으로 컨테이너 정의
→ Service로 원하는 Task 수 유지
→ AWS 자체 스케줄러가 배치 결정


[EKS 아키텍처]

EKS Cluster
├── Control Plane (AWS 관리)
│   ├── API Server
│   ├── etcd
│   ├── Scheduler
│   └── Controller Manager
└── Worker Nodes (사용자 관리)
    ├── Pod A (컨테이너)
    ├── Pod B (컨테이너)
    └── Pod C (컨테이너)

→ Deployment, StatefulSet 등으로 워크로드 정의
→ Kubernetes 스케줄러가 배치 결정
```

<br />

### (2) 기능 비교

| 항목                   | ECS                           | EKS                                  |
| ---------------------- | ----------------------------- | ------------------------------------ |
| 오케스트레이터         | AWS 자체                      | Kubernetes (오픈소스)                |
| 배포 단위              | Task                          | Pod                                  |
| 서비스 메시             | AWS App Mesh                  | Istio, Linkerd, App Mesh 등          |
| 패키지 관리            | Task Definition (JSON)        | Helm Chart, Kustomize               |
| CI/CD 통합             | CodePipeline, CodeDeploy      | ArgoCD, Flux, CodePipeline 등        |
| 오토스케일링           | Application Auto Scaling      | HPA, VPA, Karpenter, Cluster Autoscaler |
| 모니터링               | CloudWatch Container Insights | Prometheus, Grafana, CloudWatch      |
| 로깅                   | CloudWatch Logs, FireLens     | Fluentd, Fluent Bit, CloudWatch      |
| 시크릿 관리            | AWS Secrets Manager, SSM      | Kubernetes Secrets, External Secrets |
| 네트워크 모드          | awsvpc, bridge, host          | VPC CNI (Pod에 VPC IP 직접 할당)     |
| Vendor Lock-in         | 높음                          | 낮음                                 |

<br />

### (3) 운영 비교

| 항목               | ECS                              | EKS                                   |
| ------------------ | -------------------------------- | ------------------------------------- |
| 초기 설정          | 간단 (콘솔에서 수분 내 가능)     | 복잡 (네트워킹, 노드, 애드온 설정)    |
| 일상 운영          | AWS 콘솔/CLI 중심                | kubectl, Helm 등 Kubernetes 도구 중심 |
| 버전 업그레이드    | AWS가 자동 관리                  | 사용자가 계획적으로 수행              |
| 트러블슈팅         | AWS 서포트 활용                  | Kubernetes 지식 + AWS 서포트          |
| 필요 인력          | AWS 경험자                       | Kubernetes + AWS 경험자               |

<br />

## 5. 비용 비교

<br />

### (1) Control Plane 비용

| 항목               | ECS    | EKS                                   |
| ------------------ | ------ | ------------------------------------- |
| Control Plane 비용 | 무료   | $0.10/시간 (약 $73/월, 클러스터당)    |

ECS는 Control Plane 비용이 없다. EKS는 클러스터 1개당 월 약 $73의 고정 비용이 발생한다. 여러 환경(Dev, Staging, Production)을 운영하면 클러스터 수만큼 비용이 증가한다.

<br />

### (2) 컴퓨팅 비용 (EC2 기반)

EC2 인스턴스를 사용하는 경우 ECS와 EKS 모두 동일한 EC2 비용이 발생한다. 차이는 Control Plane 비용뿐이다.

**예시: t3.medium 2대 기준 (서울 리전)**

| 항목                | ECS                    | EKS                          |
| ------------------- | ---------------------- | ---------------------------- |
| EC2 비용 (온디맨드) | $0.052 × 2 × 730시간 = 약 $76/월 | $0.052 × 2 × 730시간 = 약 $76/월 |
| Control Plane       | $0                     | 약 $73/월                    |
| **월 합계**         | **약 $76**             | **약 $149**                  |

<br />

### (3) 컴퓨팅 비용 (Fargate 기반)

Fargate를 사용하면 ECS와 EKS 모두 동일한 Fargate 요금이 적용된다. 단, EKS는 Control Plane 비용이 추가된다.

**Fargate 요금 (서울 리전)**

| 리소스 | 시간당 요금     |
| ------ | --------------- |
| vCPU   | $0.04656/vCPU   |
| 메모리 | $0.00511/GB     |

**예시: 0.5 vCPU / 1GB 메모리 Task 4개 상시 운영 기준**

| 항목            | ECS                              | EKS                              |
| --------------- | -------------------------------- | -------------------------------- |
| Fargate 비용    | (0.5×$0.04656 + 1×$0.00511) × 730시간 × 4 = 약 $83/월 | 동일 약 $83/월 |
| Control Plane   | $0                               | 약 $73/월                        |
| **월 합계**     | **약 $83**                       | **약 $156**                      |

<br />

### (4) 비용 최적화 전략

**공통**

- Savings Plans 또는 Reserved Instances를 활용하여 EC2 비용을 최대 72% 절감할 수 있다.
- Fargate Spot을 활용하면 Fargate 비용을 최대 70% 절감할 수 있다 (중단 허용 워크로드에 한함).
- 적절한 리소스 사이징으로 over-provisioning을 방지한다.

**ECS 비용 최적화**

- Fargate Spot을 적극 활용한다.
- EC2 시작 유형 사용 시 Capacity Provider로 Auto Scaling을 최적화한다.

**EKS 비용 최적화**

- Karpenter를 사용하여 노드 프로비저닝을 최적화하고 Spot 인스턴스를 효율적으로 활용한다.
- 개발/테스트 환경은 EKS 클러스터를 통합하여 Control Plane 비용을 줄인다 (Namespace로 환경 분리).
- EKS Auto Mode를 사용하면 노드 관리를 AWS에 위임할 수 있다.

<br />

### (5) 규모별 비용 비교 요약

| 규모              | ECS 예상 비용  | EKS 예상 비용   | 비고                                       |
| ----------------- | -------------- | --------------- | ------------------------------------------ |
| 소규모 (Task 5개 이하)  | 약 $50~150/월  | 약 $120~220/월  | Control Plane 비용 비중이 높아 EKS 불리     |
| 중규모 (Task 10~30개)   | 약 $200~800/월 | 약 $270~870/월  | Control Plane 비용 비중이 줄어 차이 감소     |
| 대규모 (Task 50개 이상) | 약 $1,000+/월  | 약 $1,070+/월   | 컴퓨팅 비용이 대부분이므로 차이 미미         |

소규모 워크로드에서는 EKS의 Control Plane 비용($73/월)이 전체 비용에서 차지하는 비중이 크기 때문에 ECS가 비용적으로 유리하다. 규모가 커질수록 Control Plane 비용의 비중이 줄어 차이가 미미해진다.

<br />

## 6. 선택 기준

<br />

### (1) ECS를 선택해야 하는 경우

- AWS만 사용하며 멀티 클라우드 계획이 없는 경우
- 팀에 Kubernetes 경험자가 없는 경우
- 빠르게 컨테이너 환경을 구축하고 운영해야 하는 경우
- 소규모 워크로드로 비용을 최소화해야 하는 경우
- AWS 서비스와의 긴밀한 통합이 중요한 경우

<br />

### (2) EKS를 선택해야 하는 경우

- 멀티 클라우드 또는 하이브리드 클라우드 전략을 가지고 있는 경우
- 팀에 Kubernetes 운영 경험이 있는 경우
- Istio, ArgoCD 등 Kubernetes 생태계 도구를 활용해야 하는 경우
- 온프레미스에서 Kubernetes를 이미 운영 중이며 클라우드로 마이그레이션하는 경우
- 복잡한 마이크로서비스 아키텍처를 운영하며 세밀한 제어가 필요한 경우
- Vendor Lock-in을 최소화해야 하는 경우

<br />

### (3) 의사결정 흐름

```
컨테이너 오케스트레이션이 필요한가?
│
├── Kubernetes가 반드시 필요한가?
│   ├── YES → EKS
│   │   ├── 멀티 클라우드/하이브리드 요구
│   │   ├── 기존 Kubernetes 워크로드 마이그레이션
│   │   └── Kubernetes 생태계 도구 활용 필요
│   │
│   └── NO → 팀의 역량과 운영 부담을 고려
│       ├── 간단한 운영, 빠른 도입 → ECS
│       └── 향후 확장성, 유연성 중시 → EKS
│
└── 서버리스로 운영하고 싶은가?
    ├── YES → ECS + Fargate (가장 단순)
    └── 비용 최적화 필요 → ECS/EKS + EC2 (Spot, RI 활용)
```
