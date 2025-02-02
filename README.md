# AppSync Sync/Async Integration
This is a demo application that consists of an API converting a synchronous request coming from the client into an asynchronous request to the backend using AppSync Events.
In order to simulate an asynchronous backend processing, we are using an asynchronous [AWS Step Functions](https://aws.amazon.com/pt/step-functions/) workflow, which receives an event with Name and Surname as input, waits 10 seconds and then posts an event with the full name at the [AppSync Event](https://docs.aws.amazon.com/appsync/latest/eventapi/event-api-welcome.html) channel. While the asynchrnous procesing is execute, the synchronous API subscribes to the AppSync channel in order to be notified when the event arrives there.

![AppSync Events](/images/AppSync-Integration.png)

1 - The API Gateway makes a synchronous request to Lambda and waits for the response. \
2 - Lambda initiates the execution of the asynchronous workflow. \
3 - After starting the workflow execution, Lambda connects to AppSync and creates a channel to receive asynchronous notifications (channels are ephemeral and unlimited; in this case, it creates one channel per request using the workflow execution ID). \
4 - The workflow executes asynchronously, calling other workflows. \
5 - Upon completion of the main workflow, it sends a POST request to the AppSync events API with the processing result. The POST is made to the channel that was created by Lambda using the workflow execution ID. \
6 - AppSync receives the POST request and sends a notification to the subscriber, which in this case is Lambda. \
7 - Lambda receives the message asynchronously, verifies if it was successful, and if so, closes the WebSocket connection with AppSync. \
8 - Lambda sends the response to the API Gateway, which has been waiting for the synchronous response. \


# AppSync Sync/Async Integration Infrastructure

This Terraform configuration located in `/IaC/terraform` folder creates the necessary AWS infrastructure for an AppSync integration with synchronous and asynchronous capabilities.

## Resources Created

The following AWS resources are provisioned:

### IAM Roles and Policies
- Lambda execution role with permissions for:
  - Step Functions execution
  - CloudWatch Logs management
  - Secrets Manager access
- Step Functions execution role with permissions for:
  - HTTP endpoint invocation
  - EventBridge connection management
  - Secrets Manager access
  - CloudWatch Logs and X-Ray access

### Lambda Function
- Python 3.13 runtime
- 3000MB memory allocation
- 40 seconds timeout
- Environment variables for AppSync configuration

### API Gateway
- REST API with regional endpoint
- POST method on `/event` resource
- Lambda integration
- Development stage with logging enabled
- CloudWatch logging configuration

### EventBridge Connection
- API Key authorization for AppSync integration
- Credentials managed through Secrets Manager

### AppSync Events API
- Deployed via CloudFormation template, which is in the `/IaC/cloudFormation` folder (As of 2025-02-02, there's no AppSync Events API terraform resource available yet for creating it via terraform)
- Real-time endpoint configuration
- API key authentication

### Step Functions State Machine
#### This workflow is only to simulate an async processing. You can substitue it for any other async application, making the necessary adjustment.
- Workflow with the following states:
  - Wait state (10 seconds delay)
  - JSON conversion
  - Name binding
  - HTTPS API call to AppSync

## Prerequisites

Before deploying this infrastructure, ensure you have:

1. AWS CLI configured with appropriate credentials
2. Terraform installed (version 0.12 or later)
3. Required AWS permissions to create all specified resources

## Configuration

The following variables should be configured:

- `workflow_name`: Name for the Step Functions state machine
- `function_name`: Name for the Lambda function
- `lambda_file`: Path to the Lambda function code


## Deployment

1. Initialize Terraform:
```bash
terraform init
```

Review the planned changes:
```bash
terraform plan
```

Apply the configuration:
```bash
terraform plan -auto-approve
```

## Outputs
The deployment provides several important outputs:

- `lambda_function_arn`: ARN of the created Lambda function

- `state_machine_arn`: ARN of the Step Functions state machine

- `api_endpoint`: URL endpoint for the API Gateway

- `connection_arn`: ARN of the EventBridge connection

- `appsync_host`: AppSync API endpoint

- `appsync_host_realtime`: AppSync real-time endpoint

- `secretsmanager_arn`: ARN of the created Secrets Manager secret

## Clean Up
To remove all created resources:
```bash
terraform destroy -auto-approve
```

### Note: Ensure you have backed up any important data before destroying the infrastructure.

## Security Considerations
- API Gateway endpoints are publicly accessible

- Lambda function has restricted IAM permissions

- Secrets are managed through AWS Secrets Manager

- All sensitive data is encrypted at rest

- API authentication is handled via API keys