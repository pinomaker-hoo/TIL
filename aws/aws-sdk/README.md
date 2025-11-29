# AWS CLI 관리 가이드

## AWS CLI 설치 및 기본 설정

### 설치 방법

#### macOS

```bash
# Homebrew를 사용한 설치
brew install awscli

# 버전 확인
aws --version
```

#### Linux

```bash
# 설치 파일 다운로드
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 버전 확인
aws --version
```

#### Windows

```powershell
# 설치 파일 다운로드 및 실행
# https://awscli.amazonaws.com/AWSCLIV2.msi 에서 다운로드 후 설치

# 버전 확인 (PowerShell)
aws --version
```

### 기본 설정

AWS CLI를 처음 설정할 때는 `aws configure` 명령을 사용합니다:

```bash
aws configure
```

입력해야 할 정보:

- AWS Access Key ID
- AWS Secret Access Key
- Default region name (예: ap-northeast-2)
- Default output format (json, yaml, text, table)

## 여러 AWS 계정 관리하기

AWS CLI에서는 여러 계정을 프로필로 관리할 수 있습니다. 이를 통해 다양한 AWS 계정이나 역할 간에 쉽게 전환할 수 있습니다.

### 1. 프로필 생성 방법

#### 명령어로 프로필 생성

```bash
aws configure --profile [프로필이름]
```

예시:

```bash
aws configure --profile dev
aws configure --profile prod
```

#### 수동으로 프로필 생성

`~/.aws/credentials` 파일과 `~/.aws/config` 파일을 직접 편집할 수도 있습니다.

**~/.aws/credentials**:

```ini
[default]
aws_access_key_id = YOUR_DEFAULT_ACCESS_KEY
aws_secret_access_key = YOUR_DEFAULT_SECRET_KEY

[dev]
aws_access_key_id = YOUR_DEV_ACCESS_KEY
aws_secret_access_key = YOUR_DEV_SECRET_KEY

[prod]
aws_access_key_id = YOUR_PROD_ACCESS_KEY
aws_secret_access_key = YOUR_PROD_SECRET_KEY
```

**~/.aws/config**:

```ini
[default]
region = ap-northeast-2
output = json

[profile dev]
region = ap-northeast-2
output = json

[profile prod]
region = us-west-2
output = json
```

### 2. 프로필 사용 방법

#### 특정 프로필로 명령 실행

```bash
aws s3 ls --profile dev
```

#### 환경 변수로 프로필 지정

```bash
export AWS_PROFILE=dev
aws s3 ls  # dev 프로필로 실행됨
```

#### 현재 구성된 프로필 확인

```bash
aws configure list
```

### 3. IAM 역할 수임(Role Assumption)

다른 AWS 계정의 IAM 역할을 수임하여 작업할 수 있습니다.

#### config 파일에 역할 설정

**~/.aws/config**:

```ini
[profile cross-account]
role_arn = arn:aws:iam::123456789012:role/CrossAccountRole
source_profile = default
region = ap-northeast-2
```

#### 역할을 수임하여 명령 실행

```bash
aws s3 ls --profile cross-account
```

### 4. 임시 보안 자격 증명 사용

MFA(다중 인증)가 필요한 경우 임시 보안 자격 증명을 사용할 수 있습니다.

```bash
aws sts get-session-token --serial-number arn:aws:iam::123456789012:mfa/user --token-code 123456
```

응답으로 받은 임시 자격 증명을 환경 변수로 설정:

```bash
export AWS_ACCESS_KEY_ID=임시_액세스_키
export AWS_SECRET_ACCESS_KEY=임시_시크릿_키
export AWS_SESSION_TOKEN=임시_세션_토큰
```

### 5. SSO(Single Sign-On) 설정

AWS SSO를 사용하는 경우:

**~/.aws/config**:

```ini
[profile sso-user]
sso_start_url = https://my-sso-portal.awsapps.com/start
sso_region = ap-northeast-2
sso_account_id = 123456789012
sso_role_name = SSOUserRole
region = ap-northeast-2
output = json
```

SSO 로그인:

```bash
aws sso login --profile sso-user
```

## 유용한 AWS CLI 명령어

### 프로필 및 구성 관련

```bash
# 현재 구성 확인
aws configure list

# 특정 프로필의 구성 확인
aws configure list --profile dev

# 특정 설정 값 확인
aws configure get region --profile dev
```

### 자격 증명 확인

```bash
# 현재 자격 증명으로 계정 ID 확인
aws sts get-caller-identity

# 특정 프로필로 계정 ID 확인
aws sts get-caller-identity --profile prod
```

### 환경 변수 사용

```bash
# 환경 변수로 자격 증명 설정
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_DEFAULT_REGION=ap-northeast-2

# 환경 변수로 프로필 설정
export AWS_PROFILE=dev
```

## 보안 모범 사례

1. **액세스 키 정기적 교체**: 액세스 키는 90일마다 교체하는 것이 좋습니다.
2. **최소 권한 원칙**: 필요한 최소한의 권한만 부여합니다.
3. **MFA 사용**: 중요한 작업에는 MFA를 사용합니다.
4. **공유 자격 증명 파일 보호**: `~/.aws/credentials` 파일의 권한을 제한합니다.
5. **코드에 자격 증명 하드코딩 금지**: 자격 증명을 코드에 직접 포함하지 마세요.
6. **IAM 역할 사용**: 가능하면 장기 자격 증명 대신 IAM 역할을 사용합니다.

## AWS CLI 자격 증명 우선순위

AWS CLI는 다음 순서로 자격 증명을 찾습니다:

1. 명령줄 옵션 (`--region`, `--output` 등)
2. 환경 변수 (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 등)
3. CLI 자격 증명 파일 (`~/.aws/credentials`)
4. CLI 구성 파일 (`~/.aws/config`)
5. 컨테이너 자격 증명 (ECS 태스크 역할)
6. 인스턴스 프로파일 자격 증명 (EC2 인스턴스 역할)
