# AWS ECS Terraform 예제

## Terraform을 이용한 ECS 배포

이 문서에서는 Terraform을 사용하여 AWS ECS 클러스터, 작업 정의 및 서비스를 배포하는 방법에 대해 설명합니다.

## 필요 사항

- Terraform 설치 (v0.12 이상)
- AWS CLI 구성
- AWS 계정 및 적절한 권한

## 기본 디렉토리 구조

```
ecs-terraform/
├── main.tf       # 주요 리소스 정의
├── variables.tf  # 변수 정의
├── outputs.tf    # 출력 정의
└── terraform.tfvars # 변수 값 (git에 포함하지 않음)
```

## 예제 코드

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS 리전"
  default     = "ap-northeast-2"
}

variable "app_name" {
  description = "애플리케이션 이름"
  default     = "my-app"
}

variable "app_environment" {
  description = "애플리케이션 환경"
  default     = "production"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  type        = list(string)
}

variable "container_image" {
  description = "컨테이너 이미지"
  default     = "nginx:latest"
}

variable "container_port" {
  description = "컨테이너 포트"
  default     = 80
}

variable "desired_count" {
  description = "원하는 작업 수"
  default     = 2
}

variable "cpu" {
  description = "작업에 할당할 CPU 유닛"
  default     = "256"
}

variable "memory" {
  description = "작업에 할당할 메모리"
  default     = "512"
}
```

### main.tf

```hcl
provider "aws" {
  region = var.aws_region
}

# ECS 클러스터
resource "aws_ecs_cluster" "main" {
  name = "${var.app_name}-${var.app_environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = "${var.app_name}-ecs-cluster"
    Environment = var.app_environment
  }
}

# 보안 그룹
resource "aws_security_group" "ecs_sg" {
  name        = "${var.app_name}-${var.app_environment}-ecs-sg"
  description = "Allow inbound traffic for ECS service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-ecs-sg"
    Environment = var.app_environment
  }
}

# ECS 작업 실행 역할
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.app_name}-${var.app_environment}-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 로그 그룹
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.app_name}-${var.app_environment}"
  retention_in_days = 30

  tags = {
    Name        = "${var.app_name}-log-group"
    Environment = var.app_environment
  }
}

# 작업 정의
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.app_name}-${var.app_environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = var.app_name
      image     = var.container_image
      essential = true
      
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name        = "${var.app_name}-task-definition"
    Environment = var.app_environment
  }
}

# 로드 밸런서
resource "aws_lb" "main" {
  name               = "${var.app_name}-${var.app_environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_sg.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.app_name}-alb"
    Environment = var.app_environment
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.app_name}-${var.app_environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200-299"
  }

  tags = {
    Name        = "${var.app_name}-target-group"
    Environment = var.app_environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# ECS 서비스
resource "aws_ecs_service" "app" {
  name            = "${var.app_name}-${var.app_environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = var.app_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name        = "${var.app_name}-service"
    Environment = var.app_environment
  }
}
```

### outputs.tf

```hcl
output "cluster_id" {
  description = "ECS 클러스터 ID"
  value       = aws_ecs_cluster.main.id
}

output "cluster_name" {
  description = "ECS 클러스터 이름"
  value       = aws_ecs_cluster.main.name
}

output "task_definition_arn" {
  description = "ECS 작업 정의 ARN"
  value       = aws_ecs_task_definition.app.arn
}

output "service_name" {
  description = "ECS 서비스 이름"
  value       = aws_ecs_service.app.name
}

output "alb_dns_name" {
  description = "애플리케이션 로드 밸런서 DNS 이름"
  value       = aws_lb.main.dns_name
}
```

## 사용 방법

1. 필요한 변수 값을 `terraform.tfvars` 파일에 설정합니다:

```hcl
aws_region       = "ap-northeast-2"
app_name         = "my-web-app"
app_environment  = "production"
vpc_id           = "vpc-12345678"
public_subnet_ids = ["subnet-12345678", "subnet-87654321"]
container_image  = "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/my-web-app:latest"
container_port   = 80
desired_count    = 2
cpu              = "256"
memory           = "512"
```

2. Terraform 초기화:

```bash
terraform init
```

3. 실행 계획 확인:

```bash
terraform plan
```

4. 인프라 배포:

```bash
terraform apply
```

5. 인프라 삭제:

```bash
terraform destroy
```

## 주요 리소스 설명

- **aws_ecs_cluster**: ECS 컨테이너를 실행하기 위한 논리적 그룹
- **aws_ecs_task_definition**: 컨테이너 이미지, CPU/메모리 할당, 포트 매핑 등을 정의
- **aws_ecs_service**: 지정된 수의 작업을 유지하고 관리
- **aws_lb**: 애플리케이션 로드 밸런서로 트래픽 분산
- **aws_security_group**: 네트워크 트래픽 제어
- **aws_cloudwatch_log_group**: 컨테이너 로그 저장

## 고급 구성 옵션

- 오토 스케일링 설정
- 블루/그린 배포 전략
- 보안 강화 (HTTPS 지원)
- 컨테이너 간 통신 설정
- 서비스 검색 구성

## 참고 사항

- 실제 프로덕션 환경에서는 보안 및 가용성을 고려하여 추가 설정이 필요할 수 있습니다.
- 비용 최적화를 위해 Fargate Spot 인스턴스 사용을 고려해 볼 수 있습니다.
- 민감한 정보는 AWS Secrets Manager나 Parameter Store를 통해 관리하는 것이 좋습니다.
