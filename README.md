# AppSync Sync aSync Integration
This API converts a synchronous request coming from the client into an asynchronous request to the backend using AppSync Events.

![AppSync Events](/images/AppSync-Integration.png)

1 - The API Gateway makes a synchronous request to Lambda and waits for the response. \
2 - Lambda initiates the execution of the asynchronous workflow. \
3 - After starting the workflow execution, Lambda connects to AppSync and creates a channel to receive asynchronous notifications (channels are ephemeral and unlimited; in this case, it creates one channel per request using the workflow execution ID). \
4 - The workflow executes asynchronously, calling other workflows. \
5 - Upon completion of the main workflow, it sends a POST request to the AppSync events API with the processing result. The POST is made to the channel that was created by Lambda using the workflow execution ID. \
6 - AppSync receives the POST request and sends a notification to the subscriber, which in this case is Lambda. \
7 - Lambda receives the message asynchronously, verifies if it was successful, and if so, closes the WebSocket connection with AppSync. \
8 - Lambda sends the response to the API Gateway, which has been waiting for the synchronous response. \
