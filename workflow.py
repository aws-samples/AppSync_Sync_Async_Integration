import json
import boto3
import uuid
from botocore.exceptions import ClientError
import os
from typing import Dict, Any
import logging

# Create Step Functions client
sfn_client = boto3.client("stepfunctions")
state_machine_arn = os.environ["STATE_MACHINE_ARN"]
logger = logging.getLogger(__name__)

EXECUTION_PREFIX = "exec"

def start_workflow_async(event) -> Dict[str, Any]:
    try:
        execution_name = f"{EXECUTION_PREFIX}-{uuid.uuid4()}"

        # Prepare input data
        input_json = { "id": execution_name, "event": event }
        
        # Start the execution
        response = sfn_client.start_execution(
            stateMachineArn=state_machine_arn,
            name=execution_name,
            input=json.dumps(input_json)
        )

        logger.info(f"Started execution: {response["executionArn"]}")
        return {
            "status": "started",
            "executionArn": response["executionArn"],
            "id": execution_name
        }
        
    except ClientError as e:
        logger.error(f"AWS Client Error: {str(e)}")  # Add logging for debugging
        return {
            "status": "error",  # Make status consistent with success case
            "error": str(e)     # Convert exception to string
        }
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return {
            "status": "error",
            "error": str(e)
        }