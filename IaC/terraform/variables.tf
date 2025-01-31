variable "function_name" {
  type = string
  default = "lambda_appsyc_events_demo"
}

variable "workflow_name" {
    type = string
    default = "sfn_appsync_events_demo"
}

variable "appync_namespace" {
    type = string
    default = "AsyncEvents"
}

variable "AppSync_Host"{
    type = string
}

variable "AppSync_Host_RealTime"{
    type = string

}

variable "secret_manager_arn" {
  type = string
}

locals {
    region = "us-east-1"
    lambda_file = "${path.module}/../../lambda.zip"
}



output "region" {
  value = local.region
}