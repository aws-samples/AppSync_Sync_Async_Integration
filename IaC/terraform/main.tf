#The IAM Role for Lambda Function
resource "aws_iam_role" "lambda_iam_role" {
    name_prefix = "LambdaStepFunctionsAppSyncExecutions-"
    inline_policy {
        name = "StepFunctionsExecution"

        policy = jsonencode({
            Version = "2012-10-17"
            "Statement": [
            {
                "Effect": "Allow",
                "Action": "states:StartExecution",
                "Resource": "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${var.workflow_name}"
            }
        ]
        })
    }

    inline_policy {
        name = "CloudWatchLogGroup"

        policy = jsonencode({
            Version = "2012-10-17"
            "Statement": [
            {
                "Effect": "Allow",
                "Action": "logs:CreateLogGroup",
                "Resource": "arn:aws:logs:${local.region}:${local.account_id}:*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": [
                    "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${var.function_name}:*"
                ]
            }
        ]
        })
    }

    inline_policy {
        name = "secretsmanager"

        policy = jsonencode({
            Version = "2012-10-17"
            "Statement": [
                {
                    "Sid": "VisualEditor0",
                    "Effect": "Allow",
                    "Action": "secretsmanager:GetSecretValue",
                    "Resource": "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:AppSyncEventAPIKEY*"
                }
            ]
        
        })
    }

    assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": "sts:AssumeRole",
                    "Principal": {
                        "Service": "lambda.amazonaws.com"
                    },
                    "Effect": "Allow",
                    "Sid": ""
                }
            ]
    }
    EOF
}

#Create the Lambda function
resource "aws_lambda_function" "AppSync_Sync_Async_Lambda" {
    
    function_name = var.function_name
    filename = local.lambda_file
    source_code_hash = local.lambda_file
    handler = "app.lambda_handler"
    runtime = "python3.13"
    role = aws_iam_role.lambda_iam_role.arn
    timeout = 40
    memory_size = 3000
    publish = true

    environment {
    variables = {
      API_HOST = aws_cloudformation_stack.appsync_event.outputs["AppSyncHost"],
      API_KEY = "AppSyncEventAPIKEY",
      API_URL = "wss://${aws_cloudformation_stack.appsync_event.outputs["AppSyncRealTimeEndpoint"]}/event/realtime",
      STATE_MACHINE_ARN = "arn:aws:states:${local.region}:${local.account_id}:stateMachine:${var.workflow_name}"
      APPSYNC_NAMESPACE = local.appync_namespace
    }
  }
    
}

#The Lambda permission for API Gateway
resource "aws_lambda_permission" "with_api_gateway" {
    statement_id = "AllowExecutionFromAPIGateway"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.AppSync_Sync_Async_Lambda.function_name}"
    principal = "apigateway.amazonaws.com"
    source_arn = "arn:aws:execute-api:${local.region}:${local.account_id}:*/*"
}

#create an API gateway API
resource "aws_api_gateway_rest_api" "api_gateway" {
    name = "${var.function_name}-api"
    description = "API Gateway for AppSync Integration"
    endpoint_configuration {
        types = ["REGIONAL"]
    }
}

#Creating an API Resource
resource "aws_api_gateway_resource" "events" {
    path_part = "event"
    parent_id = aws_api_gateway_rest_api.api_gateway.root_resource_id
    rest_api_id = aws_api_gateway_rest_api.api_gateway.id
}

#Creating an API method for the Resource
resource "aws_api_gateway_method" "method" {
    rest_api_id = aws_api_gateway_rest_api.api_gateway.id
    resource_id = aws_api_gateway_resource.events.id
    http_method = "POST"
    authorization = "NONE"
}

#Setting up the API integration with Lambda Function
resource "aws_api_gateway_integration" "integration" {
    rest_api_id = aws_api_gateway_rest_api.api_gateway.id
    resource_id = aws_api_gateway_resource.events.id
    http_method = aws_api_gateway_method.method.http_method
    integration_http_method = aws_api_gateway_method.method.http_method
    type = "AWS_PROXY"
    uri = aws_lambda_function.AppSync_Sync_Async_Lambda.invoke_arn
    
}

#Creating the API Deployment for using it in the Stage
resource "aws_api_gateway_deployment" "api_deployment" {
    rest_api_id = aws_api_gateway_rest_api.api_gateway.id
    triggers = {
        redeployment = sha1(jsonencode(aws_api_gateway_integration.integration))
    }
    lifecycle {
        create_before_destroy = true
    }
}

#Creating the API Stage to publish the API and have the API endpoint
resource "aws_api_gateway_stage" "api_stage" {
    deployment_id = aws_api_gateway_deployment.api_deployment.id
    rest_api_id = aws_api_gateway_rest_api.api_gateway.id
    stage_name = "dev"
}

#Seeting up the Stage, enabling Log info
resource "aws_api_gateway_method_settings" "all" {
    rest_api_id = aws_api_gateway_rest_api.api_gateway.id
    stage_name = aws_api_gateway_stage.api_stage.stage_name
    method_path = "*/*"
    settings {
        metrics_enabled = true
        logging_level = "INFO"
    }
}

#Creating the Connection for the Step Functions workflow - HTTP Endpoint stage.
#This connection allows to the Step Functions workflow to post back the event into the AppSync channel.
resource "aws_cloudwatch_event_connection" "EventBridgeConn" {
    name = "EventBridgeConn"
    description = "EventBridgeConnection"
    authorization_type = "API_KEY"
    auth_parameters {
        api_key {
            key  = "x-api-key"
            value = data.aws_secretsmanager_secret_version.current.secret_string
        }
    }
}

#Creating the Step Functions workflow
resource "aws_sfn_state_machine" "sfn_state_machine" {
  name     = var.workflow_name
  role_arn = aws_iam_role.iam_for_sfn.arn

  definition = <<EOF
    {
        "QueryLanguage": "JSONPath",
        "Comment": "A description of my state machine",
        "StartAt": "Wait",
        "States": {
            "Wait": {
            "Type": "Wait",
            "Seconds": 10,
            "Next": "convert json"
            },
            "convert json": {
            "Type": "Pass",
            "Next": "bind names",
            "ResultPath": "$",
            "Parameters": {
                "id.$": "$.id",
                "evento.$": "States.StringToJson($.event)"
            }
            },
            "bind names": {
            "Type": "Pass",
            "Next": "Call HTTPS APIs",
            "Parameters": {
                "id.$": "$.id",
                "nome_completo.$": "States.Format('{} {}', $.evento.nome, $.evento.sobrenome)"
            }
            },
            "Call HTTPS APIs": {
            "Type": "Task",
            "Resource": "arn:aws:states:::http:invoke",
            "Parameters": {
                "ApiEndpoint": "https://${aws_cloudformation_stack.appsync_event.outputs["AppSyncHost"]}/event",
                "Method": "POST",
                "InvocationConfig": {
                "ConnectionArn": "${aws_cloudwatch_event_connection.EventBridgeConn.arn}"
                },
                "RequestBody": {
                "channel.$": "States.Format('${local.appync_namespace}/{}',$.id)",
                "events.$": "States.Array(States.Format('\\{\"nome_completo\":\"{}\"\\}', $.nome_completo))"
                }
            },
            "Retry": [
                {
                "ErrorEquals": [
                    "States.ALL"
                ],
                "BackoffRate": 2,
                "IntervalSeconds": 1,
                "MaxAttempts": 3,
                "JitterStrategy": "FULL"
                }
            ],
            "End": true
            }
        }
        }
    EOF
}

#Creating the IAM Role for Step Function
resource "aws_iam_role" "iam_for_sfn" {
  name = "stepfunctions-appsync-role"

  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "TrustPolicy1",
                "Effect": "Allow",
                "Principal": {
                    "Service": "states.amazonaws.com"
                },
                "Action": "sts:AssumeRole",
                "Condition": {
                    "StringEquals": {
                        "aws:SourceAccount": "${local.account_id}"
                    },
                    "ArnLike": {
                        "aws:SourceArn": "arn:aws:states:${local.region}:${local.account_id}:stateMachine:*"
                    }
                }
            }
        ]
    }
    EOF

    inline_policy {
        name = "workflow-permissions"
        policy = jsonencode({
            "Version": "2012-10-17",
            "Statement": [
            {
                "Effect": "Allow",
                "Sid": "InvokeHttpEndpoint1",
                "Action": [
                    "states:InvokeHTTPEndpoint"
                ],
                "Resource": [
                    "arn:aws:states:${local.region}:${local.account_id}:stateMachine:*"
                ],
                "Condition": {
                    "StringEquals": {
                        "states:HTTPEndpoint": [
                            "https://${aws_cloudformation_stack.appsync_event.outputs["AppSyncHost"]}/event"
                        ],
                        "states:HTTPMethod": [
                            "POST"
                        ]
                    }
                }
            },
            {
                "Effect": "Allow",
                "Sid": "RetrieveConnectionCredentials1",
                "Action": [
                    "events:RetrieveConnectionCredentials"
                ],
                "Resource": [
                    "${aws_cloudwatch_event_connection.EventBridgeConn.arn}"
                ]
            },
            {
                "Effect": "Allow",
                "Sid": "GetAndDescribeSecretValue1",
                "Action": [
                    "secretsmanager:GetSecretValue",
                    "secretsmanager:DescribeSecret"
                ],
                "Resource": [
                    "arn:aws:secretsmanager:${local.region}:${local.account_id}:secret:events!connection/EventBridgeConn/*"
                ]
            },
            {
                "Sid": "CloudWatchLogsFullAccess",
                "Effect": "Allow",
                "Action": [
                    "logs:*",
                    "cloudwatch:GenerateQuery"
                ],
                "Resource": "*"
            },
            {
                "Effect": "Allow",
                "Action": [
                    "xray:PutTraceSegments",
                    "xray:PutTelemetryRecords",
                    "xray:GetSamplingRules",
                    "xray:GetSamplingTargets"
                ],
                "Resource": [
                    "*"
                ]
            }
        ]
    })
    }
    
}

#As of today (2025-02-02) there's no AppSync Events API terraform resource available. 
#Therefore, we are creating the Event API using cloudFormation.
resource "aws_cloudformation_stack" "appsync_event"{
    name = "appsync-events"
    template_body = file("${path.module}/../cloudFormation/template.yaml")

}


# Output the ARN of the Lambda function
output "lambda_function_arn" {
    value = aws_lambda_function.AppSync_Sync_Async_Lambda.arn
}
# Output the ARN of the State Machine
output "sate_machine_arn" {
    value = aws_sfn_state_machine.sfn_state_machine.arn
}
# Output the API Gateway Endpoint
output "api_endpoint" {
    value = aws_api_gateway_stage.api_stage.invoke_url
}
# Output the ARN of the EventBridge Connection
output "connection_arn" {
    value = aws_cloudwatch_event_connection.EventBridgeConn.arn
}

output "appsync_host" {
    value = aws_cloudformation_stack.appsync_event.outputs["AppSyncHost"]
}

output "appsync_host_realtime" {
    value = aws_cloudformation_stack.appsync_event.outputs["AppSyncRealTimeEndpoint"]
}

output "secretsmanager_arn" {
    value = aws_cloudformation_stack.appsync_event.outputs["SecretsManagerARN"]
}