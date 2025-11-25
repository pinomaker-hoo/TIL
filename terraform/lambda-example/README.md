# AWS Lambda Terraform 예제

이 예제는 Terraform을 사용하여 AWS Lambda 함수를 생성하는 방법을 보여줍니다. 이 예제에서는 다음 리소스를 생성합니다:

- Lambda 함수
- Lambda 실행 역할 (IAM Role)
- CloudWatch 로그 그룹
- API Gateway HTTP API (Lambda 함수 호출용)

## 사전 요구사항

- [Terraform](https://www.terraform.io/downloads.html) 설치 (v1.0.0 이상)
- AWS 계정 및 적절한 권한을 가진 AWS CLI 구성

## 파일 구조

- `main.tf`: 주요 Terraform 구성 파일
- `variables.tf`: 변수 정의 파일
- `outputs.tf`: 출력 정의 파일
- `lambda_function.js`: Lambda 함수 코드

## 사용 방법

1. AWS CLI가 구성되어 있는지 확인합니다:

```bash
aws configure
```

2. Terraform 초기화:

```bash
terraform init
```

3. Terraform 계획 확인:

```bash
terraform plan
```

4. 리소스 생성:

```bash
terraform apply
```

5. 리소스 삭제:

```bash
terraform destroy
```

## Lambda 함수 테스트

배포가 완료되면 다음 명령어로 Lambda 함수를 직접 호출할 수 있습니다:

```bash
aws lambda invoke --function-name example-lambda-function --payload '{}' response.json
cat response.json
```

또는 출력된 API Gateway URL을 사용하여 브라우저나 curl로 테스트할 수 있습니다:

```bash
curl $(terraform output -raw lambda_invoke_url)
```

## 주요 리소스

- `aws_lambda_function`: Lambda 함수 리소스
- `aws_iam_role`: Lambda 실행을 위한 IAM 역할
- `aws_apigatewayv2_api`: HTTP API Gateway
- `aws_cloudwatch_log_group`: Lambda 로그를 저장하는 CloudWatch 로그 그룹
