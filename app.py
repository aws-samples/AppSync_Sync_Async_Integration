import json
import logging
from typing import Dict, Any
import workflow as wf
from websocket_handler import WebSocketHandler

# Configure logging
logger = logging.getLogger(__name__)

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    AWS Lambda handler function.
    
    Args:
        event: AWS Lambda event
        context: AWS Lambda context
    
    Returns:
        Dict containing status code and response body
    """

    logger.info(json.dumps(event))
    try:
        handler = WebSocketHandler()
    
    
        sfn_response = wf.start_workflow_async(event["body"])
        
        if sfn_response["status"] == "started":
            handler.execution_name = sfn_response["id"]
            handler.start_websocket_connection()
            
            return {
                'statusCode': 200,
                'body': json.dumps({ 
                        "id": handler.execution_name,
                        "nome completo": handler.final_name
                        })
            }
        else:
            raise ValueError("Workflow failed to start")
            
    except Exception as e:
        logger.error("Error: %s", str(e))
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Error processing request',
                'error': str(e)
            })
        }
