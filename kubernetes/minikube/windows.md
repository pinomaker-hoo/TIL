# Minikube 로컬 환경 구성 (Windows)

## 개요

Windows에서 Minikube를 설치하고 로컬 쿠버네티스 클러스터를 구성하는 과정을 정리한다. Windows 10/11 기준이며, 드라이버는 **Docker Desktop(WSL2 백엔드)** 을 사용하는 방식을 기본으로 하고 Hyper-V 방식을 대안으로 설명한다.

<br />

## 목차

[1. 사전 준비](#1-사전-준비)

[2. WSL2 활성화](#2-wsl2-활성화)

[3. Docker Desktop 설치](#3-docker-desktop-설치)

[4. 패키지 매니저 설치 (winget / Chocolatey)](#4-패키지-매니저-설치-winget--chocolatey)

[5. kubectl 설치](#5-kubectl-설치)

[6. Minikube 설치](#6-minikube-설치)

[7. 클러스터 시작](#7-클러스터-시작)

[8. 동작 확인](#8-동작-확인)

[9. 샘플 애플리케이션 배포](#9-샘플-애플리케이션-배포)

[10. 자주 쓰는 설정](#10-자주-쓰는-설정)

[11. 대안 : Hyper-V 드라이버](#11-대안--hyper-v-드라이버)

[12. 대안 : WSL2 내부에서 직접 사용](#12-대안--wsl2-내부에서-직접-사용)

[13. 트러블슈팅](#13-트러블슈팅)

[14. 정리(삭제)](#14-정리삭제)

<br />
<br />

## 1. 사전 준비

<br />

| 항목   | 요구 사항                                                                   |
| ------ | --------------------------------------------------------------------------- |
| OS     | Windows 10 버전 2004(빌드 19041) 이상 또는 Windows 11, 64bit                |
| CPU    | 2 코어 이상, 가상화(VT-x / AMD-V) 지원 및 BIOS에서 활성화                    |
| 메모리 | 여유 메모리 4GB 이상 (8GB 이상 권장)                                        |
| 디스크 | 여유 공간 20GB 이상                                                         |
| 기타   | 관리자 권한, 인터넷 연결                                                    |

가상화 활성화 여부 확인 (작업 관리자 > 성능 > CPU > "가상화: 사용" 표시):

```powershell
systeminfo | findstr /i "Hyper-V"
```

Windows 버전 확인:

```powershell
winver
```

> 이 문서의 명령어는 **PowerShell(관리자 권한)** 에서 실행하는 것을 기준으로 한다. 시작 메뉴에서 `PowerShell`을 검색한 뒤 마우스 오른쪽 클릭 → "관리자 권한으로 실행".

<br />

## 2. WSL2 활성화

<br />

Docker Desktop은 WSL2 백엔드에서 가장 잘 동작한다. 관리자 PowerShell에서 실행:

```powershell
wsl --install
```

이 명령 하나로 다음이 모두 처리된다.

- Windows 기능 "Linux용 Windows 하위 시스템" 활성화
- Windows 기능 "가상 머신 플랫폼" 활성화
- WSL2 커널 설치
- 기본 배포판(Ubuntu) 설치

완료 후 **재부팅**한다. 재부팅하면 Ubuntu 초기 설정 창이 뜨며 사용자 이름/비밀번호를 입력한다.

WSL2가 기본 버전인지 확인:

```powershell
wsl --set-default-version 2
wsl -l -v
#   NAME      STATE           VERSION
# * Ubuntu    Running         2
```

이미 WSL이 설치된 경우 최신 커널로 업데이트:

```powershell
wsl --update
```

> `wsl --install`이 동작하지 않는 구버전 Windows 10이라면 아래 기능을 수동으로 활성화한 뒤 재부팅하고, [WSL2 커널 업데이트 패키지](https://aka.ms/wsl2kernel)를 설치한다.
>
> ```powershell
> dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
> dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
> ```

<br />

## 3. Docker Desktop 설치

<br />

[Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) 설치 파일을 받아 실행하거나 winget으로 설치한다.

```powershell
winget install -e --id Docker.DockerDesktop
```

설치 마법사에서 **"Use WSL 2 instead of Hyper-V"** 옵션을 체크한다. 설치 후 재부팅이 필요할 수 있다.

Docker Desktop을 실행한 뒤 `Settings > General`에서 **"Use the WSL 2 based engine"** 이 켜져 있는지 확인한다. 시스템 트레이의 고래 아이콘이 안정되면 준비 완료.

확인:

```powershell
docker version
docker run --rm hello-world
```

`Settings > Resources > WSL Integration`에서 사용 중인 배포판(Ubuntu)의 통합을 켜두면 WSL 안에서도 `docker` 명령을 쓸 수 있다.

> **메모리 조정** : WSL2는 기본적으로 호스트 메모리의 50%까지 사용한다. 조정하려면 `%UserProfile%\.wslconfig` 파일을 생성한다.
>
> ```ini
> [wsl2]
> memory=8GB
> processors=4
> ```
>
> 저장 후 `wsl --shutdown` 으로 재시작.

<br />

## 4. 패키지 매니저 설치 (winget / Chocolatey)

<br />

Windows 10 최신 버전과 Windows 11에는 **winget**이 기본 포함되어 있다.

```powershell
winget --version
```

winget이 없거나 Chocolatey를 선호한다면 관리자 PowerShell에서:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

```powershell
choco --version
```

이하 문서는 winget 기준으로 작성하고 Chocolatey 명령을 병기한다.

<br />

## 5. kubectl 설치

<br />

```powershell
# winget
winget install -e --id Kubernetes.kubectl

# Chocolatey
choco install kubernetes-cli -y
```

새 PowerShell 창을 열고 확인:

```powershell
kubectl version --client
```

> Docker Desktop을 설치하면 `C:\Program Files\Docker\Docker\resources\bin\kubectl.exe`가 함께 설치된다. 별도 설치한 kubectl과 버전이 다르면 PATH 순서에 따라 어느 것이 실행되는지 `Get-Command kubectl`로 확인한다.

<br />

## 6. Minikube 설치

<br />

```powershell
# winget
winget install -e --id Kubernetes.minikube

# Chocolatey
choco install minikube -y
```

수동 설치를 원한다면 [minikube-installer.exe](https://storage.googleapis.com/minikube/releases/latest/minikube-installer.exe)를 받아 실행하거나, 바이너리를 직접 내려받아 PATH에 추가한다.

```powershell
New-Item -Path 'C:\minikube' -ItemType Directory -Force
Invoke-WebRequest -OutFile 'C:\minikube\minikube.exe' -Uri 'https://github.com/kubernetes/minikube/releases/latest/download/minikube-windows-amd64.exe' -UseBasicParsing

# PATH 에 추가 (사용자 환경변수)
$oldPath = [Environment]::GetEnvironmentVariable('Path', [EnvironmentVariableTarget]::User)
if ($oldPath.Split(';') -inotcontains 'C:\minikube') {
  [Environment]::SetEnvironmentVariable('Path', ('{0};C:\minikube' -f $oldPath), [EnvironmentVariableTarget]::User)
}
```

새 PowerShell 창을 열고 확인:

```powershell
minikube version
```

<br />

## 7. 클러스터 시작

<br />

Docker Desktop이 실행 중인지 확인한 뒤 클러스터를 시작한다.

```powershell
minikube start --driver=docker
```

처음 실행 시 쿠버네티스 노드 이미지(약 1GB)를 내려받는다.

```
😄  minikube v1.3x.x on Microsoft Windows 11 Pro 10.0.2xxxx
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

```powershell
minikube start --driver=docker --cpus=4 --memory=8192 --disk-size=40g
```

> docker 드라이버의 리소스 상한은 WSL2에 할당된 리소스(`.wslconfig`)에 의해 결정된다.

docker 드라이버를 기본값으로 고정:

```powershell
minikube config set driver docker
minikube config set cpus 4
minikube config set memory 8192
```

<br />

## 8. 동작 확인

<br />

```powershell
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

대시보드 (브라우저 자동 실행):

```powershell
minikube dashboard
```

<br />

## 9. 샘플 애플리케이션 배포

<br />

```powershell
# Deployment 생성
kubectl create deployment hello-nginx --image=nginx:alpine

# NodePort 서비스로 노출
kubectl expose deployment hello-nginx --type=NodePort --port=80

# 파드 상태 확인
kubectl get pods -w
```

Windows + docker 드라이버 조합에서는 `minikube ip`로 직접 접근할 수 없으므로 `minikube service`를 사용한다. 이 명령은 터널을 열어두므로 터미널을 닫으면 접근이 끊긴다.

```powershell
minikube service hello-nginx
# 🏃  Starting tunnel for service hello-nginx.
# 브라우저가 http://127.0.0.1:xxxxx 로 열림
```

URL만 출력:

```powershell
minikube service hello-nginx --url
```

또는 포트포워딩:

```powershell
kubectl port-forward svc/hello-nginx 8080:80
# http://localhost:8080
```

정리:

```powershell
kubectl delete svc hello-nginx
kubectl delete deployment hello-nginx
```

<br />

## 10. 자주 쓰는 설정

<br />

### (1) 로컬에서 빌드한 이미지 사용하기

**방법 A. minikube의 Docker 데몬에 직접 빌드**

PowerShell에서는 `eval`이 없으므로 아래처럼 실행한다.

```powershell
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker build -t my-app:local .

# 원래대로 복구
& minikube docker-env --shell powershell -u | Invoke-Expression
```

CMD를 사용하는 경우:

```cmd
@FOR /f "tokens=*" %i IN ('minikube -p minikube docker-env --shell cmd') DO @%i
```

**방법 B. 로컬 이미지를 minikube로 복사**

```powershell
docker build -t my-app:local .
minikube image load my-app:local
```

매니페스트에서 `imagePullPolicy`를 설정해야 레지스트리 pull을 시도하지 않는다.

```yaml
containers:
  - name: my-app
    image: my-app:local
    imagePullPolicy: Never
```

<br />

### (2) Ingress 사용하기

```powershell
minikube addons enable ingress
kubectl get pods -n ingress-nginx
```

docker 드라이버에서는 Ingress 접근을 위해 별도 **관리자 PowerShell** 창에서 `minikube tunnel`을 실행해둔다.

```powershell
minikube tunnel
```

`C:\Windows\System32\drivers\etc\hosts` 파일을 관리자 권한으로 열어 호스트를 매핑한다.

```
127.0.0.1 my-app.local
```

<br />

### (3) LoadBalancer 타입 서비스

`minikube tunnel`을 실행하면 `LoadBalancer` 타입 서비스에 `EXTERNAL-IP`가 할당된다.

```powershell
minikube tunnel
kubectl get svc
# NAME     TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
# my-svc   LoadBalancer   10.96.x.x      127.0.0.1     80:3xxxx/TCP
```

<br />

### (4) 유용한 애드온

```powershell
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable registry
```

<br />

### (5) 쿠버네티스 버전 지정

```powershell
minikube start --kubernetes-version=v1.31.0
```

<br />

### (6) 여러 클러스터(프로파일) 운영

```powershell
minikube start -p dev --cpus=2 --memory=4096
minikube start -p test --cpus=2 --memory=4096

minikube profile list
minikube profile dev
kubectl config use-context dev
```

<br />

## 11. 대안 : Hyper-V 드라이버

<br />

Docker Desktop을 설치할 수 없는 환경(라이선스 등)이라면 Windows 내장 하이퍼바이저인 Hyper-V를 드라이버로 사용할 수 있다. **Windows Pro / Enterprise / Education**에서만 가능하다(Home 에디션은 Hyper-V 미지원).

관리자 PowerShell에서 Hyper-V 활성화 후 재부팅:

```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
```

클러스터 시작 (관리자 PowerShell 필요):

```powershell
minikube start --driver=hyperv --cpus=4 --memory=8192
```

기본값으로 고정:

```powershell
minikube config set driver hyperv
```

Hyper-V 드라이버는 VM이 자체 IP를 가지므로 `minikube ip`로 NodePort에 직접 접근할 수 있다.

```powershell
minikube ip
# 172.x.x.x
# http://172.x.x.x:<NodePort>
```

외부 네트워크를 쓰려면 Hyper-V 관리자에서 외부 가상 스위치를 만들고 지정한다.

```powershell
minikube start --driver=hyperv --hyperv-virtual-switch="External Switch"
```

<br />

## 12. 대안 : WSL2 내부에서 직접 사용

<br />

Windows 쪽이 아니라 WSL2 Ubuntu 안에서 Linux 방식 그대로 minikube를 쓰는 방법도 있다. Docker Desktop의 WSL Integration이 켜져 있으면 Ubuntu에서 바로 `docker`를 사용할 수 있다.

```bash
# Ubuntu (WSL2) 에서
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

minikube start --driver=docker
```

이 경우 kubeconfig는 WSL 내부(`~/.kube/config`)에 생성되므로 Windows 쪽 kubectl과는 분리된다. VS Code Remote-WSL 등으로 개발 환경 전체를 WSL에 두는 경우 이 방식이 더 자연스럽다.

<br />

## 13. 트러블슈팅

<br />

### `Exiting due to PROVIDER_DOCKER_NOT_RUNNING`

Docker Desktop이 실행되지 않은 상태. 시스템 트레이에서 Docker Desktop을 실행하고 안정될 때까지 기다린 뒤 재시도한다.

<br />

### `Exiting due to DRV_CP_ENDPOINT` / `Exiting due to GUEST_PROVISION`

WSL2 또는 Docker 네트워크가 꼬인 경우가 많다.

```powershell
minikube delete
wsl --shutdown
# Docker Desktop 재시작 후
minikube start
```

<br />

### `minikube ip` 로 접근이 안 됨

docker 드라이버에서는 정상 동작이다. `minikube service`, `kubectl port-forward`, `minikube tunnel` 중 하나를 사용한다. Hyper-V 드라이버라면 직접 접근 가능하다.

<br />

### `The system cannot find the file specified` / PATH 문제

설치 후 **새 PowerShell 창**을 열지 않으면 PATH가 갱신되지 않는다. 창을 새로 연 뒤 `Get-Command minikube`, `Get-Command kubectl`로 실행 경로를 확인한다.

<br />

### `Hyper-V ... requires elevated privileges`

Hyper-V 드라이버는 관리자 PowerShell에서만 동작한다.

<br />

### WSL2가 메모리를 과도하게 점유

`%UserProfile%\.wslconfig`에 상한을 걸고 `wsl --shutdown`으로 재시작한다.

```ini
[wsl2]
memory=8GB
processors=4
swap=0
```

<br />

### 바이러스 백신 / 방화벽이 통신을 차단

일부 백신은 Docker 네트워크나 `minikube tunnel`을 차단한다. 예외 목록에 `minikube.exe`, `docker.exe`, `com.docker.backend.exe`를 추가한다.

<br />

### 클러스터가 꼬였을 때

```powershell
minikube delete
minikube start
```

캐시까지 완전히 초기화:

```powershell
minikube delete --all --purge
```

<br />

### 로그 확인

```powershell
minikube logs
minikube logs --problems
```

<br />

## 14. 정리(삭제)

<br />

```powershell
# 클러스터 정지 (상태 유지)
minikube stop

# 클러스터 삭제
minikube delete

# 모든 프로파일 + 캐시 삭제
minikube delete --all --purge

# 도구 제거
winget uninstall Kubernetes.minikube
winget uninstall Kubernetes.kubectl
winget uninstall Docker.DockerDesktop

# Chocolatey 로 설치한 경우
choco uninstall minikube kubernetes-cli -y
```

Hyper-V 드라이버를 썼다면 Hyper-V 관리자에 남은 VM/가상 스위치도 확인해 삭제한다.
