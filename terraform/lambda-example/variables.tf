variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-northeast-2"  # Seoul region
}

variable "lambda_function_name" {
  description = "Name of the Lambda function"
  type        = string
  default     = "example-lambda-function"
}

variable "lambda_runtime" {
  description = "Runtime for Lambda function"
  type        = string
  default     = "nodejs18.x"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function (MB)"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Timeout for Lambda function (seconds)"
  type        = number
  default     = 10
}
