variable "function_name" {
  type = string
  default = "lambda_appsyc_events_demo"
}

variable "workflow_name" {
    type = string
    default = "sfn_appsync_events_demo"
}

locals {
    region = "us-east-1"
    lambda_file = "${path.module}/../../lambda.zip"
    appync_namespace = "AsyncEvents"
}

output "region" {
  value = local.region
}