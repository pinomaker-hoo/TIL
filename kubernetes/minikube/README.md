# Minikube

## 개요

Minikube는 로컬 환경에서 단일 노드 쿠버네티스 클러스터를 구동할 수 있게 해주는 도구다. 실제 클라우드(EKS, GKE 등)에 클러스터를 올리기 전에 로컬에서 쿠버네티스를 학습하고, 매니페스트를 테스트하는 용도로 사용한다.

<br />

## Minikube 구조

<br />

```
┌──────────────────────────────────────────────┐
│  로컬 PC (macOS / Windows)                    │
│                                              │
│   kubectl ──────▶ minikube VM / Container    │
│                    ┌──────────────────────┐  │
│                    │  Control Plane       │  │
│                    │  (api-server, etcd,  │  │
│                    │   scheduler, ...)    │  │
│                    ├──────────────────────┤  │
│                    │  Worker (same node)  │  │
│                    │   Pod  Pod  Pod      │  │
│                    └──────────────────────┘  │
└──────────────────────────────────────────────┘
```

- Minikube는 **드라이버(driver)** 를 통해 VM 또는 컨테이너 안에 쿠버네티스 노드를 띄운다.
- 드라이버는 OS별로 선택지가 다르다.
  - macOS : `docker`, `hyperkit`, `qemu`, `vfkit`, `virtualbox`
  - Windows : `docker`, `hyperv`, `virtualbox`
- 가장 간단하고 범용적인 방법은 **Docker Desktop 위에서 `docker` 드라이버를 사용하는 것**이다.

<br />

## 목차

| OS      | 문서                        |
| ------- | --------------------------- |
| macOS   | [mac.md](./mac.md)          |
| Windows | [windows.md](./windows.md)  |

<br />

## 공통 명령어 치트시트

<br />

```bash
# 클러스터 생명주기
minikube start                 # 클러스터 시작 (없으면 생성)
minikube stop                  # 클러스터 정지 (상태 보존)
minikube delete                # 클러스터 삭제
minikube delete --all          # 모든 프로파일 삭제
minikube status                # 상태 확인

# 리소스 지정하여 시작
minikube start --cpus=4 --memory=8192 --driver=docker

# 여러 클러스터(프로파일) 운영
minikube start -p dev
minikube profile list
minikube profile dev

# 애드온
minikube addons list
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable metrics-server

# 대시보드
minikube dashboard

# 서비스 접근
minikube service <service-name>            # 브라우저로 열기
minikube service <service-name> --url      # URL만 출력
minikube tunnel                            # LoadBalancer 타입 서비스 노출

# 로컬 이미지를 minikube에서 바로 사용
minikube image load <image>:<tag>
eval $(minikube docker-env)                # (mac/linux) 셸을 minikube docker 데몬에 연결

# 노드 접속 / 로그
minikube ssh
minikube logs

# 버전
minikube version
kubectl version
```
