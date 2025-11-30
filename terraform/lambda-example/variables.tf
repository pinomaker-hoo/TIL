# AWS 리전 설정
# 모든 AWS 리소스가 생성될 리전을 지정
variable "aws_region" {
  description = "AWS region for all resources"  # 모든 리소스에 대한 AWS 리전
  type        = string                        # 변수 타입: 문자열
  default     = "ap-northeast-2"              # 기본값: 서울 리전
}

# Lambda 함수 이름 설정
# AWS Lambda 함수의 이름을 정의
variable "lambda_function_name" {
  description = "Name of the Lambda function"  # Lambda 함수의 이름
  type        = string                       # 변수 타입: 문자열
  default     = "example-lambda-function"     # 기본값: example-lambda-function
}

# Lambda 런타임 설정
# Lambda 함수가 실행될 환경(언어 및 버전)을 지정
variable "lambda_runtime" {
  description = "Runtime for Lambda function"  # Lambda 함수의 런타임
  type        = string                      # 변수 타입: 문자열
  default     = "nodejs18.x"                 # 기본값: Node.js 18.x 버전
}

# Lambda 함수 메모리 크기 설정
# Lambda 함수가 사용할 메모리 양을 MB 단위로 지정
# 메모리가 클수록 성능이 좋지만 비용도 증가
variable "lambda_memory_size" {
  description = "Memory size for Lambda function (MB)"  # Lambda 함수의 메모리 크기(MB)
  type        = number                             # 변수 타입: 숫자
  default     = 128                                # 기본값: 128MB (최소 크기)
}

# Lambda 함수 실행 제한 시간 설정
# Lambda 함수가 실행될 수 있는 최대 시간을 초 단위로 지정
# 최대 15분(900초)까지 설정 가능
variable "lambda_timeout" {
  description = "Timeout for Lambda function (seconds)"  # Lambda 함수의 제한 시간(초)
  type        = number                              # 변수 타입: 숫자
  default     = 10                                   # 기본값: 10초
}
