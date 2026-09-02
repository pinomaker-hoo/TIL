# Minikube 로컬 환경 구성 (macOS)

## 개요

macOS에서 Minikube를 설치하고 로컬 쿠버네티스 클러스터를 구성하는 과정을 정리한다. Apple Silicon(M1/M2/M3/M4)과 Intel Mac 모두 동일한 흐름이며, 차이가 있는 부분은 별도로 표기한다.

<br />

## 목차

[1. 사전 준비](#1-사전-준비)

[2. Homebrew 설치](#2-homebrew-설치)

[3. Docker Desktop 설치](#3-docker-desktop-설치)

[4. kubectl 설치](#4-kubectl-설치)

[5. Minikube 설치](#5-minikube-설치)

[6. 클러스터 시작](#6-클러스터-시작)

[7. 동작 확인](#7-동작-확인)

[8. 샘플 애플리케이션 배포](#8-샘플-애플리케이션-배포)

[9. 정리(삭제)](#9-정리삭제)

<br />
<br />

## 1. 사전 준비

<br />

| 항목   | 요구 사항                                             |
| ------ | ----------------------------------------------------- |
| OS     | macOS 12(Monterey) 이상 권장                          |
| CPU    | 2 코어 이상                                           |
| 메모리 | 여유 메모리 4GB 이상 (8GB 이상 권장)                  |
| 디스크 | 여유 공간 20GB 이상                                   |
| 기타   | 인터넷 연결, 관리자 권한                              |

CPU 아키텍처 확인:

```bash
uname -m
# arm64  → Apple Silicon
# x86_64 → Intel
```

<br />

## 2. Homebrew 설치

<br />

macOS 패키지 매니저인 Homebrew를 사용해 대부분의 도구를 설치한다. 이미 설치되어 있다면 건너뛴다.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Apple Silicon의 경우 설치 후 PATH 등록이 필요하다.

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

확인:

```bash
brew --version
```

<br />

## 3. Docker Desktop 설치

<br />

Minikube의 드라이버로 **docker**를 사용하는 것이 가장 간단하다. Docker Desktop을 설치하면 Docker 데몬이 함께 제공된다.

```bash
brew install --cask docker
```

설치 후 `Applications > Docker`를 실행하여 Docker Desktop을 한 번 띄워야 데몬이 기동된다. 메뉴바에 고래 아이콘이 뜨고 "Docker Desktop is running" 상태가 되면 준비 완료.

확인:

```bash
docker version
docker run --rm hello-world
```

> **참고** : Docker Desktop 대신 무료 대안을 쓰고 싶다면 [OrbStack](https://orbstack.dev/) 또는 [Colima](https://github.com/abiosoft/colima)를 사용할 수 있다. 둘 다 `docker` CLI 호환이므로 이후 과정은 동일하다.
>
> ```bash
> # Colima 예시
> brew install colima docker
> colima start --cpu 4 --memory 8
> ```

<br />

## 4. kubectl 설치

<br />

kubectl은 쿠버네티스 클러스터와 통신하는 CLI다.

```bash
brew install kubectl
```

확인:

```bash
kubectl version --client
```

> Minikube 자체에도 kubectl이 내장되어 있어 `minikube kubectl -- get pods` 형태로 사용할 수도 있지만, 별도 설치하는 편이 편하다.

<br />

## 5. Minikube 설치

<br />

```bash
brew install minikube
```

확인:

```bash
minikube version
```

Homebrew 없이 바이너리로 직접 설치하려면:

```bash
# Apple Silicon
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-arm64
sudo install minikube-darwin-arm64 /usr/local/bin/minikube

# Intel
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-darwin-amd64
sudo install minikube-darwin-amd64 /usr/local/bin/minikube
```

<br />

## 6. 클러스터 시작

<br />

Docker Desktop이 실행 중인지 확인한 뒤 클러스터를 시작한다.

```bash
minikube start --driver=docker
```

처음 실행 시 쿠버네티스 노드 이미지(약 1GB)를 내려받으므로 시간이 걸린다. 정상적으로 뜨면 아래와 비슷한 출력이 나온다.

```
😄  minikube v1.3x.x on Darwin 15.x (arm64)
✨  Using the docker driver based on user configuration
👍  Starting "minikube" primary control-plane node in "minikube" cluster
🚜  Pulling base image ...
🔥  Creating docker container (CPUs=2, Memory=4000MB) ...
🐳  Preparing Kubernetes v1.3x.x on Docker 2x.x ...
🔎  Verifying Kubernetes components...
🌟  Enabled addons: storage-provisioner, default-storageclass
🏄  Done! kubectl is now configured to use "minikube" cluster and "default" namespace by default
```

리소스를 명시적으로 지정하려면:

```bash
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=40g
```

> Docker Desktop의 `Settings > Resources`에서 허용한 CPU/메모리 범위 내에서만 할당된다. 8GB를 주려면 Docker Desktop에도 8GB 이상 할당되어 있어야 한다.

docker 드라이버를 기본값으로 고정해두면 매번 `--driver`를 붙이지 않아도 된다.

```bash
minikube config set driver docker
minikube config set cpus 4
minikube config set memory 8192
```

<br />

## 7. 동작 확인

<br />

```bash
# 클러스터 상태
minikube status

# kubectl 컨텍스트가 minikube로 잡혔는지 확인
kubectl config current-context
# → minikube

# 노드 확인
kubectl get nodes
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.3x.x

# 시스템 파드 확인
kubectl get pods -n kube-system
```

대시보드도 확인해본다. 브라우저가 자동으로 열린다.

```bash
minikube dashboard
```

<br />

## 8. 샘플 애플리케이션 배포

<br />

간단한 nginx를 배포해 외부에서 접근되는지 확인한다.

```bash
# Deployment 생성
kubectl create deployment hello-nginx --image=nginx:alpine

# NodePort 서비스로 노출
kubectl expose deployment hello-nginx --type=NodePort --port=80

# 파드가 Running 될 때까지 대기
kubectl get pods -w
```

macOS에서 docker 드라이버를 사용하면 minikube 노드 IP(`minikube ip`)에 직접 접근할 수 없다. 대신 `minikube service`를 통해 터널을 열어 접근한다.

```bash
minikube service hello-nginx
# 🏃  Starting tunnel for service hello-nginx.
# 브라우저가 http://127.0.0.1:xxxxx 로 열림
```

URL만 필요하다면:

```bash
minikube service hello-nginx --url
```

또는 포트포워딩:

```bash
kubectl port-forward svc/hello-nginx 8080:80
# http://localhost:8080
```

정리:

```bash
kubectl delete svc hello-nginx
kubectl delete deployment hello-nginx
```

<br />

## 9. 정리(삭제)

<br />

```bash
# 클러스터 정지 (상태 유지, 다시 start 하면 복구)
minikube stop

# 클러스터 삭제
minikube delete

# 모든 프로파일 + 캐시 삭제
minikube delete --all --purge

# 도구 자체 제거
brew uninstall minikube kubectl
brew uninstall --cask docker
```
