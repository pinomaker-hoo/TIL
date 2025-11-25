# Terraform으로 AWS Lambda 생성하기

Terraform을 사용하여 AWS Lambda 함수를 생성하는 방법을 알아보겠습니다.

## 필요한 리소스

AWS Lambda 함수를 생성하기 위해서는 다음과 같은 리소스가 필요합니다:

1. Lambda 함수 자체
2. Lambda 실행 역할 (IAM Role)
3. Lambda 함수 코드 (ZIP 파일)
4. CloudWatch 로그 그룹 (선택사항)
5. API Gateway (선택사항, 함수 호출용)

## 기본 구성

### 프로바이더 설정

```hcl
provider "aws" {
  region = "ap-northeast-2"  # Seoul region
}
```

### IAM 역할 생성

Lambda 함수가 AWS 서비스에 접근하기 위한 IAM 역할이 필요합니다:

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# 기본 Lambda 실행 정책 연결
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

### Lambda 함수 코드 준비

Lambda 함수 코드를 ZIP 파일로 압축해야 합니다:

```hcl
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.js"
  output_path = "${path.module}/lambda_function.zip"
}
```

### Lambda 함수 생성

```hcl
resource "aws_lambda_function" "example_lambda" {
  function_name    = "example-lambda-function"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "nodejs18.x"
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = "dev"
    }
  }
}
```

### CloudWatch 로그 그룹 생성

Lambda 함수의 로그를 저장할 CloudWatch 로그 그룹을 생성합니다:

```hcl
resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.example_lambda.function_name}"
  retention_in_days = 14
}
```

## API Gateway 연결 (선택사항)

Lambda 함수를 HTTP 요청으로 호출하기 위한 API Gateway를 설정할 수 있습니다:

```hcl
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "lambda-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.lambda_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.example_lambda.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.example_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*/hello"
}
```

## 출력 정의

```hcl
output "lambda_function_name" {
  value = aws_lambda_function.example_lambda.function_name
}

output "lambda_function_arn" {
  value = aws_lambda_function.example_lambda.arn
}

output "api_gateway_url" {
  value = "${aws_apigatewayv2_stage.lambda_stage.invoke_url}/hello"
}
```

## Lambda 함수 코드 예제 (JavaScript)

```javascript
exports.handler = async (event) => {
  console.log('Event: ', JSON.stringify(event, null, 2));
  
  const response = {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      message: 'Hello from Lambda!',
      timestamp: new Date().toISOString(),
      event: event,
    }),
  };
  
  return response;
};
```

## 실행 방법

1. Terraform 초기화:
```bash
terraform init
```

2. 실행 계획 확인:
```bash
terraform plan
```

3. 리소스 생성:
```bash
terraform apply
```

4. 리소스 삭제:
```bash
terraform destroy
```

## 전체 예제 코드

전체 예제 코드는 [lambda-example](./lambda-example) 디렉토리에서 확인할 수 있습니다.

## 참고 사항

- Lambda 함수의 코드가 변경될 때마다 `source_code_hash`가 변경되어 Terraform이 함수를 업데이트합니다.
- API Gateway를 통해 Lambda 함수를 호출할 수 있습니다.
- CloudWatch 로그 그룹을 통해 Lambda 함수의 로그를 확인할 수 있습니다.
