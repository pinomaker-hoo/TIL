# AWS 프로바이더 설정
# region: AWS 리전 지정 (variables.tf에서 정의)
# profile: AWS CLI에 설정된 프로필 이름 (mas9 프로필 사용)
provider "aws" {
  region = var.aws_region
  profile = "mas9"
}

# Lambda 함수 실행을 위한 IAM 역할 생성
# 이 역할은 Lambda 서비스가 맡아서 실행할 수 있는 권한을 가짐
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"  # IAM 역할 이름

  # 신뢰 관계 정책: Lambda 서비스가 이 역할을 맡을 수 있도록 허용
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"  # 역할 수임 액션
        Effect = "Allow"          # 허용
        Principal = {
          Service = "lambda.amazonaws.com"  # Lambda 서비스만 이 역할을 맡을 수 있음
        }
      }
    ]
  })
}

# Lambda 기본 실행 정책을 역할에 연결
# 이 정책은 CloudWatch Logs에 로그를 쓸 수 있는 권한을 제공
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name  # 위에서 생성한 역할 이름
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"  # AWS 관리형 정책 ARN
}

# Lambda 함수 코드를 ZIP 파일로 압축
# Lambda 배포를 위해서는 코드를 ZIP 형식으로 압축해야 함
data "archive_file" "lambda_zip" {
  type        = "zip"                                 # 압축 유형
  source_file = "${path.module}/lambda_function.js"  # 압축할 소스 파일 경로
  output_path = "${path.module}/lambda_function.zip" # 출력 ZIP 파일 경로
}

# Lambda 함수 리소스 생성
resource "aws_lambda_function" "example_lambda" {
  function_name    = var.lambda_function_name                      # Lambda 함수 이름 (variables.tf에서 정의)
  filename         = data.archive_file.lambda_zip.output_path      # ZIP 파일 경로
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256  # 코드 변경 감지를 위한 해시값
  role             = aws_iam_role.lambda_role.arn                 # 실행 역할 ARN
  handler          = "lambda_function.handler"                    # 핸들러 함수 지정 (파일명.함수명)
  runtime          = var.lambda_runtime                           # 런타임 (variables.tf에서 정의, 예: nodejs18.x)
  timeout          = var.lambda_timeout                           # 제한 시간 (초)
  memory_size      = var.lambda_memory_size                       # 메모리 크기 (MB)

  # 환경 변수 설정
  environment {
    variables = {
      ENVIRONMENT = "dev"  # 개발 환경임을 나타내는 환경 변수
    }
  }
}

# Lambda 함수의 로그를 저장할 CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.example_lambda.function_name}"  # 로그 그룹 이름
  retention_in_days = 14  # 로그 보존 기간 (14일)
}



# 출력값은 outputs.tf 파일에 정의되어 있음
