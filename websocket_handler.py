import json
import websocket
import base64
import logging
from typing import Dict, Any, Optional
import os

# Configure logging
logger = logging.getLogger()
logger.setLevel("INFO")

# Constants
CONNECTION_INIT_TYPE = "connection_init"
SUBSCRIBE_TYPE = "subscribe"
WEBSOCKET_PROTOCOL = "aws-appsync-event-ws"
SUCCESS_STATUS = "success"
DEFAULT_EXECUTION_NAME = "default"   

class WebSocketHandler:
    def __init__(self):
        self.execution_name: str = DEFAULT_EXECUTION_NAME
        self.message_queue: Dict[str, Any] = {}
        self.ws: Optional[websocket.WebSocketApp] = None
        self._validate_environment()
        self.final_name: Dict[str, Any] = {}

    def _validate_environment(self) -> None:
        """Validate required environment variables."""
        required_vars = ["API_HOST", "API_URL", "API_KEY"]
        missing_vars = [var for var in required_vars if not os.environ.get(var)]
        if missing_vars:
            raise ValueError(f"Missing required environment variables: {', '.join(missing_vars)}")

    def _create_connection_header(self) -> str:
        """Create and encode connection header."""
        connection_header = {
            "host": os.environ["API_HOST"],
            "x-api-key": os.environ["API_KEY"],
            "Sec-WebSocket-Protocol": WEBSOCKET_PROTOCOL
        }
        return base64.b64encode(json.dumps(connection_header).encode()).decode()

    def on_message(self, ws: websocket.WebSocketApp, message: str) -> None:
        """Handle incoming WebSocket messages."""
        logger.info("Message received: %s", message)
        try:
            message_dict = json.loads(message)
            required_keys = ["id", "type", "event"]
            
            if all(key in message_dict for key in required_keys):
                event_json = json.loads(message_dict["event"])
                
                if (message_dict["id"] == self.execution_name and 
                    message_dict["type"] == "data"):
                    
                    self.final_name = event_json["nome_completo"]
                    logger.info("Message received: %s", self.final_name)
                    logger.info("Successfully received return message")
                    logger.info("Ending processing")
                    
                    self.message_queue = {
                        "status": SUCCESS_STATUS,
                        "executionID": message_dict["id"]
                    }
                    ws.close()
        except json.JSONDecodeError as e:
            logger.error("Failed to parse message: %s", str(e))
        except Exception as e:
            logger.error("Error processing message: %s", str(e))

    def on_error(self, ws: websocket.WebSocketApp, error: Exception) -> None:
        """Handle WebSocket errors."""
        logger.error("WebSocket error: %s", str(error))
        raise ValueError("WebSocket error: %s", str(error))

    def on_close(self, ws: websocket.WebSocketApp, 
                close_status_code: Optional[int], 
                close_msg: Optional[str]) -> None:
        """Handle WebSocket connection closure."""
        logger.info("Connection closed. Status code: %s, Message: %s", 
                   close_status_code, close_msg)

    def on_open(self, ws: websocket.WebSocketApp) -> None:
        try:
            """Handle WebSocket connection opening and send initial messages."""
            logger.info("Connection opened")
            
            # Send connection initialization
            connection_init = {"type": CONNECTION_INIT_TYPE}
            ws.send(json.dumps(connection_init))

            # Send subscription
            subscription_msg = {
                "type": SUBSCRIBE_TYPE,
                "id": self.execution_name,
                "channel": f"testAppSync/{self.execution_name}",
                "authorization": {
                    "x-api-key": os.environ["API_KEY"],
                    "host": os.environ["API_HOST"]
                }
            }
            
            logger.info("Sending subscription")
            ws.send(json.dumps(subscription_msg))
        except Exception as e:
            self.on_error = e

    def start_websocket_connection(self) -> None:
        try: 
            """Initialize and start WebSocket connection."""
            header_str = self._create_connection_header()
            
            self.ws = websocket.WebSocketApp(
                os.environ["API_URL"],
                subprotocols=[WEBSOCKET_PROTOCOL, f'header-{header_str}'],
                on_open=self.on_open,
                on_message=self.on_message,
                on_error=self.on_error,
                on_close=self.on_close
            )
            self.ws.run_forever()
        except Exception as e:
            return e