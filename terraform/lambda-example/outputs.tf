# Lambda 함수 이름 출력
# 생성된 Lambda 함수의 이름을 Terraform 출력값으로 제공
# terraform output lambda_function_name 명령으로 확인 가능
output "lambda_function_name" {
  description = "Name of the Lambda function"  # Lambda 함수의 이름
  value       = aws_lambda_function.example_lambda.function_name  # 생성된 Lambda 함수의 이름 참조
}

# Lambda 함수 ARN 출력
# ARN(Amazon Resource Name)은 AWS 리소스의 고유 식별자
# 다른 AWS 서비스에서 Lambda 호출시 필요
output "lambda_function_arn" {
  description = "ARN of the Lambda function"  # Lambda 함수의 ARN
  value       = aws_lambda_function.example_lambda.arn  # 생성된 Lambda 함수의 ARN 참조
}

# API Gateway 관련 출력값은 제거되었습니다
