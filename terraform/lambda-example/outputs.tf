output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.example_lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.example_lambda.arn
}

output "lambda_invoke_url" {
  description = "URL to invoke the Lambda function via API Gateway"
  value       = "${aws_apigatewayv2_stage.lambda_stage.invoke_url}/hello"
}

output "api_gateway_id" {
  description = "ID of the API Gateway"
  value       = aws_apigatewayv2_api.lambda_api.id
}
