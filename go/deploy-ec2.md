# Go EC2 배포 가이드

> AWS EC2 인스턴스에 Go 애플리케이션을 배포하는 방법을 정리한다. 바이너리 직접 배포부터 systemd 서비스 등록, Nginx 리버스 프록시, CodeDeploy 자동화까지 단계별로 다룬다.

## 목차

1. [EC2 배포 아키텍처](#1-ec2-배포-아키텍처)
2. [EC2 인스턴스 준비](#2-ec2-인스턴스-준비)
3. [바이너리 직접 배포](#3-바이너리-직접-배포)
4. [systemd 서비스 등록](#4-systemd-서비스-등록)
5. [Nginx 리버스 프록시](#5-nginx-리버스-프록시)
6. [환경 변수와 시크릿 관리](#6-환경-변수와-시크릿-관리)
7. [배포 자동화 (GitHub Actions + CodeDeploy)](#7-배포-자동화-github-actions--codedeploy)
8. [로그 관리](#8-로그-관리)
9. [모니터링과 알림](#9-모니터링과-알림)
10. [무중단 배포 (Blue/Green)](#10-무중단-배포-bluegreen)
11. [핵심 요약](#11-핵심-요약)

---

## 1. EC2 배포 아키텍처

```
                    ┌──────────────┐
                    │   Route 53   │
                    │  (DNS)       │
                    └──────┬───────┘
                           │
                    ┌──────▼───────┐
                    │     ALB      │
                    │ (포트 80/443) │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐ ┌──▼──────┐ ┌──▼──────────┐
       │   EC2 #1    │ │ EC2 #2  │ │   EC2 #3    │
       │ Go App:8080 │ │ :8080   │ │   :8080     │
       │ + Nginx:80  │ │         │ │             │
       └─────────────┘ └─────────┘ └─────────────┘
              │
       ┌──────▼──────┐
       │    RDS      │
       │ PostgreSQL  │
       └─────────────┘
```

### EC2 배포의 장점

- ✅ 인스턴스를 완전히 제어할 수 있음
- ✅ 기존 인프라와의 통합이 쉬움
- ✅ 디버깅 시 SSH 접속으로 직접 확인 가능
- ✅ Go 바이너리 특성상 런타임 설치 불필요

### EC2 배포의 단점

- ❌ 서버 관리(패치, 보안 업데이트) 직접 수행
- ❌ 스케일링 설정을 직접 구성해야 함
- ❌ ECS/K8s 대비 배포 자동화가 복잡

---

## 2. EC2 인스턴스 준비

### 인스턴스 생성

```bash
# AWS CLI로 EC2 인스턴스 생성
aws ec2 run-instances \
  --image-id ami-0c9c942bd7bf113a2 \  # Amazon Linux 2023
  --instance-type t3.micro \
  --key-name my-key-pair \
  --security-group-ids sg-xxxxxxxx \
  --subnet-id subnet-xxxxxxxx \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=myapp-api}]'
```

### 보안 그룹 설정

| 유형 | 포트 | 소스 | 용도 |
|------|------|------|------|
| SSH | 22 | 내 IP | 서버 접속 |
| HTTP | 80 | 0.0.0.0/0 | 웹 트래픽 (Nginx) |
| HTTPS | 443 | 0.0.0.0/0 | SSL 트래픽 |
| Custom TCP | 8080 | ALB SG | Go 앱 (ALB에서만 접근) |

### 초기 서버 설정

```bash
# SSH 접속
ssh -i my-key-pair.pem ec2-user@<EC2-PUBLIC-IP>

# 시스템 업데이트
sudo yum update -y

# 필수 패키지 설치
sudo yum install -y nginx git

# 앱 디렉토리 생성
sudo mkdir -p /opt/myapp
sudo chown ec2-user:ec2-user /opt/myapp
```

> Go 바이너리는 정적 컴파일되므로 **Go 런타임을 서버에 설치할 필요가 없다**.

---

## 3. 바이너리 직접 배포

### 로컬에서 빌드 후 전송

```bash
# 1. Linux용 바이너리 빌드 (로컬 머신에서)
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
  -ldflags="-s -w" \
  -o myapp ./cmd/api

# 2. EC2로 바이너리 전송
scp -i my-key-pair.pem myapp ec2-user@<EC2-IP>:/opt/myapp/

# 3. .env 파일 전송 (필요 시)
scp -i my-key-pair.pem .env.production ec2-user@<EC2-IP>:/opt/myapp/.env

# 4. SSH 접속 후 실행
ssh -i my-key-pair.pem ec2-user@<EC2-IP>
cd /opt/myapp
chmod +x myapp
./myapp
```

### ARM64 인스턴스 (Graviton) 사용 시

Graviton 인스턴스(t4g, m7g 등)는 비용이 ~20% 저렴하다.

```bash
# ARM64용 빌드
CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build \
  -ldflags="-s -w" \
  -o myapp ./cmd/api
```

---

## 4. systemd 서비스 등록

프로세스를 systemd 서비스로 등록하면 **자동 시작, 자동 재시작, 로그 관리**가 가능하다.

### 서비스 파일 생성

```bash
sudo vi /etc/systemd/system/myapp.service
```

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=MyApp API Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=ec2-user
Group=ec2-user
WorkingDirectory=/opt/myapp
ExecStart=/opt/myapp/myapp
Restart=always
RestartSec=5

# 환경 변수 파일
EnvironmentFile=/opt/myapp/.env

# 보안 설정
NoNewPrivileges=true
ProtectSystem=full
ProtectHome=true

# 리소스 제한
LimitNOFILE=65535
LimitNPROC=4096

# 로그
StandardOutput=journal
StandardError=journal
SyslogIdentifier=myapp

[Install]
WantedBy=multi-user.target
```

### 환경 변수 파일

```bash
# /opt/myapp/.env
PORT=8080
ENVIRONMENT=production
DATABASE_URL=postgres://user:pass@rds-endpoint:5432/myapp?sslmode=require
JWT_SECRET=production-secret-key
LOG_LEVEL=info
```

### 서비스 관리 명령어

```bash
# 서비스 등록 및 시작
sudo systemctl daemon-reload
sudo systemctl enable myapp    # 부팅 시 자동 시작
sudo systemctl start myapp     # 서비스 시작

# 서비스 관리
sudo systemctl status myapp    # 상태 확인
sudo systemctl stop myapp      # 정지
sudo systemctl restart myapp   # 재시작

# 로그 확인
sudo journalctl -u myapp -f              # 실시간 로그
sudo journalctl -u myapp --since today   # 오늘 로그
sudo journalctl -u myapp -n 100          # 최근 100줄
```

---

## 5. Nginx 리버스 프록시

Nginx를 Go 앱 앞에 두면 **SSL 종료, 정적 파일 서빙, 로드밸런싱, 레이트 리밋** 등을 처리할 수 있다.

### Nginx 설정

```nginx
# /etc/nginx/conf.d/myapp.conf
upstream myapp {
    server 127.0.0.1:8080;
    keepalive 32;
}

server {
    listen 80;
    server_name api.example.com;

    # Let's Encrypt SSL 인증서 발급 시 필요
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # HTTP → HTTPS 리다이렉트
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name api.example.com;

    # SSL 인증서 (Let's Encrypt)
    ssl_certificate /etc/letsencrypt/live/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.example.com/privkey.pem;

    # SSL 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;

    # Gzip 압축
    gzip on;
    gzip_types application/json text/plain application/javascript;

    # 요청 크기 제한
    client_max_body_size 10M;

    # 프록시 설정
    location / {
        proxy_pass http://myapp;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";

        # 타임아웃
        proxy_connect_timeout 10s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
    }

    # 헬스 체크 (ALB용)
    location /health {
        proxy_pass http://myapp;
        access_log off;
    }
}
```

### SSL 인증서 발급 (Let's Encrypt)

```bash
# Certbot 설치
sudo yum install -y certbot python3-certbot-nginx

# SSL 인증서 발급
sudo certbot --nginx -d api.example.com

# 자동 갱신 설정
sudo systemctl enable certbot-renew.timer
```

### Nginx 시작

```bash
# 설정 검증
sudo nginx -t

# Nginx 시작
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl reload nginx   # 설정 변경 후 리로드
```

---

## 6. 환경 변수와 시크릿 관리

### AWS Systems Manager Parameter Store

```bash
# 파라미터 저장
aws ssm put-parameter \
  --name "/myapp/production/DATABASE_URL" \
  --value "postgres://user:pass@rds:5432/myapp" \
  --type SecureString

aws ssm put-parameter \
  --name "/myapp/production/JWT_SECRET" \
  --value "super-secret-key" \
  --type SecureString
```

```go
// 앱에서 Parameter Store 조회
import (
    "context"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/ssm"
)

func loadFromSSM(ctx context.Context, paramName string) (string, error) {
    cfg, err := config.LoadDefaultConfig(ctx, config.WithRegion("ap-northeast-2"))
    if err != nil {
        return "", err
    }

    client := ssm.NewFromConfig(cfg)
    result, err := client.GetParameter(ctx, &ssm.GetParameterInput{
        Name:           &paramName,
        WithDecryption: boolPtr(true),
    })
    if err != nil {
        return "", err
    }

    return *result.Parameter.Value, nil
}
```

### 배포 스크립트에서 환경 변수 생성

```bash
#!/bin/bash
# deploy.sh - EC2에서 실행되는 배포 스크립트

# Parameter Store에서 환경 변수 가져와서 .env 생성
aws ssm get-parameters-by-path \
  --path "/myapp/production/" \
  --with-decryption \
  --query "Parameters[*].[Name,Value]" \
  --output text | while read name value; do
    key=$(echo $name | awk -F'/' '{print $NF}')
    echo "${key}=${value}" >> /opt/myapp/.env
done

# 서비스 재시작
sudo systemctl restart myapp
```

---

## 7. 배포 자동화 (GitHub Actions + CodeDeploy)

### 전체 흐름

```
GitHub Push → GitHub Actions → S3에 아티팩트 업로드 → CodeDeploy → EC2에 배포
```

### appspec.yml (CodeDeploy 설정)

```yaml
# appspec.yml (프로젝트 루트)
version: 0.0
os: linux

files:
  - source: myapp
    destination: /opt/myapp/
  - source: scripts/
    destination: /opt/myapp/scripts/

permissions:
  - object: /opt/myapp/myapp
    owner: ec2-user
    group: ec2-user
    mode: 755

hooks:
  ApplicationStop:
    - location: scripts/stop.sh
      timeout: 30
      runas: root

  BeforeInstall:
    - location: scripts/before-install.sh
      timeout: 30
      runas: root

  AfterInstall:
    - location: scripts/after-install.sh
      timeout: 30
      runas: root

  ApplicationStart:
    - location: scripts/start.sh
      timeout: 30
      runas: root

  ValidateService:
    - location: scripts/validate.sh
      timeout: 60
      runas: ec2-user
```

### 배포 스크립트

```bash
# scripts/stop.sh
#!/bin/bash
sudo systemctl stop myapp || true
```

```bash
# scripts/before-install.sh
#!/bin/bash
mkdir -p /opt/myapp
# 이전 바이너리 백업
if [ -f /opt/myapp/myapp ]; then
    cp /opt/myapp/myapp /opt/myapp/myapp.backup
fi
```

```bash
# scripts/after-install.sh
#!/bin/bash
cd /opt/myapp
chown ec2-user:ec2-user myapp
chmod +x myapp
```

```bash
# scripts/start.sh
#!/bin/bash
sudo systemctl daemon-reload
sudo systemctl start myapp
```

```bash
# scripts/validate.sh
#!/bin/bash
# 헬스 체크로 배포 검증
sleep 5
for i in {1..10}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health)
    if [ "$STATUS" = "200" ]; then
        echo "헬스 체크 통과"
        exit 0
    fi
    echo "대기 중... ($i/10)"
    sleep 3
done
echo "헬스 체크 실패!"
exit 1
```

### GitHub Actions 워크플로우

```yaml
# .github/workflows/deploy-ec2.yml
name: Deploy to EC2

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: 테스트
        run: go test ./...

      - name: 빌드
        run: |
          CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
            -ldflags="-s -w -X main.version=${{ github.sha }}" \
            -o myapp ./cmd/api

      - name: 배포 패키지 생성
        run: |
          mkdir -p deploy
          cp myapp deploy/
          cp appspec.yml deploy/
          cp -r scripts deploy/
          cd deploy && zip -r ../deploy.zip .

      - name: S3 업로드
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - run: aws s3 cp deploy.zip s3://myapp-deploy/deploy-${{ github.sha }}.zip

      - name: CodeDeploy 배포
        run: |
          aws deploy create-deployment \
            --application-name myapp \
            --deployment-group-name production \
            --s3-location bucket=myapp-deploy,key=deploy-${{ github.sha }}.zip,bundleType=zip \
            --deployment-config-name CodeDeployDefault.OneAtATime
```

---

## 8. 로그 관리

### CloudWatch Logs 에이전트

```bash
# CloudWatch 에이전트 설치
sudo yum install -y amazon-cloudwatch-agent

# 에이전트 설정
sudo vi /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/myapp/system",
            "log_stream_name": "{instance_id}"
          }
        ]
      },
      "journald": {
        "collect_list": [
          {
            "unit": "myapp",
            "log_group_name": "/myapp/application",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

```bash
# 에이전트 시작
sudo systemctl enable amazon-cloudwatch-agent
sudo systemctl start amazon-cloudwatch-agent
```

### 구조화된 로깅 (Go 앱 내)

```go
import (
    "log/slog"
    "os"
)

func initLogger() *slog.Logger {
    return slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    }))
}

// 사용
logger := initLogger()
logger.Info("서버 시작", "port", 8080)
logger.Error("DB 연결 실패", "error", err)

// 출력: {"time":"2024-01-01T00:00:00Z","level":"INFO","msg":"서버 시작","port":8080}
```

---

## 9. 모니터링과 알림

### CloudWatch 알림 설정

```bash
# CPU 80% 이상 시 알림
aws cloudwatch put-metric-alarm \
  --alarm-name "myapp-high-cpu" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --alarm-actions arn:aws:sns:ap-northeast-2:123456789:alerts \
  --dimensions Name=InstanceId,Value=i-xxxxxxxxxx
```

### Auto Scaling Group (선택)

트래픽에 따라 EC2 인스턴스를 자동으로 늘리거나 줄인다.

```bash
# 시작 템플릿 생성
aws ec2 create-launch-template \
  --launch-template-name myapp-template \
  --launch-template-data '{
    "ImageId": "ami-xxxxxxxx",
    "InstanceType": "t3.small",
    "KeyName": "my-key-pair",
    "SecurityGroupIds": ["sg-xxxxxxxx"],
    "UserData": "'$(base64 -w0 userdata.sh)'"
  }'

# Auto Scaling Group 생성
aws autoscaling create-auto-scaling-group \
  --auto-scaling-group-name myapp-asg \
  --launch-template LaunchTemplateName=myapp-template,Version='$Latest' \
  --min-size 2 \
  --max-size 6 \
  --desired-capacity 2 \
  --target-group-arns arn:aws:elasticloadbalancing:...:targetgroup/myapp/... \
  --vpc-zone-identifier "subnet-aaa,subnet-bbb"
```

---

## 10. 무중단 배포 (Blue/Green)

### CodeDeploy Blue/Green 배포

```bash
# 배포 그룹 생성 (Blue/Green)
aws deploy create-deployment-group \
  --application-name myapp \
  --deployment-group-name production \
  --deployment-config-name CodeDeployDefault.AllAtOnce \
  --auto-scaling-groups myapp-asg \
  --load-balancer-info targetGroupInfoList=[{name=myapp-tg}] \
  --deployment-style deploymentType=BLUE_GREEN,deploymentOption=WITH_TRAFFIC_CONTROL \
  --blue-green-deployment-configuration '{
    "terminateBlueInstancesOnDeploymentSuccess": {
      "action": "TERMINATE",
      "terminationWaitTimeInMinutes": 10
    },
    "deploymentReadyOption": {
      "actionOnTimeout": "CONTINUE_DEPLOYMENT"
    }
  }' \
  --service-role-arn arn:aws:iam::123456789:role/CodeDeployRole
```

### 수동 무중단 배포 (간단 버전)

CodeDeploy 없이도 간단한 무중단 배포가 가능하다.

```bash
#!/bin/bash
# deploy-zero-downtime.sh

APP_DIR=/opt/myapp
NEW_BINARY=$1

# 1. 새 바이너리 전송
cp $NEW_BINARY $APP_DIR/myapp.new
chmod +x $APP_DIR/myapp.new

# 2. 새 바이너리 헬스 체크 (다른 포트에서 테스트)
PORT=8081 $APP_DIR/myapp.new &
NEW_PID=$!
sleep 3

if curl -sf http://localhost:8081/health > /dev/null; then
    echo "새 버전 헬스 체크 통과"
    kill $NEW_PID
else
    echo "새 버전 헬스 체크 실패! 롤백"
    kill $NEW_PID
    exit 1
fi

# 3. 바이너리 교체 및 재시작
mv $APP_DIR/myapp $APP_DIR/myapp.old
mv $APP_DIR/myapp.new $APP_DIR/myapp
sudo systemctl restart myapp

# 4. 검증
sleep 3
if curl -sf http://localhost:8080/health > /dev/null; then
    echo "배포 성공!"
    rm -f $APP_DIR/myapp.old
else
    echo "배포 실패! 롤백 중..."
    mv $APP_DIR/myapp.old $APP_DIR/myapp
    sudo systemctl restart myapp
    exit 1
fi
```

---

## 11. 핵심 요약

- Go 바이너리는 **런타임 설치 불필요** — SCP로 바이너리만 전송하면 바로 실행 가능
- **systemd**로 서비스를 등록하면 자동 시작, 자동 재시작, journalctl 로그 관리가 가능하다
- **Nginx 리버스 프록시**로 SSL 종료, Gzip 압축, 요청 제한 등을 처리한다
- **AWS SSM Parameter Store**로 시크릿을 안전하게 관리한다
- **GitHub Actions + CodeDeploy**로 Push → 빌드 → S3 → EC2 배포를 자동화한다
- **CloudWatch**로 로그 수집 및 CPU/메모리 알림을 설정한다
- **Auto Scaling Group + ALB**로 트래픽에 따라 자동 스케일링한다
- **Blue/Green 배포**로 무중단 배포를 구현할 수 있다

## 참고 자료

- [AWS EC2 사용 설명서](https://docs.aws.amazon.com/ec2/)
- [AWS CodeDeploy 사용 설명서](https://docs.aws.amazon.com/codedeploy/)
- [systemd 서비스 가이드](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Nginx 리버스 프록시 가이드](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/)
