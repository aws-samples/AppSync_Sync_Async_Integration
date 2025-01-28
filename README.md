# AppSync_Sync_aSync_Integration
This API converts a synchronous request coming from the client into an asynchronous request to the backend using AppSync Events.

![AppSync Events](https://gitlab.aws.dev/rrmarq/AppSync_Sync_aSync_Integration/-/blob/main/images/AppSync-Integration.png?ref_type=heads)

1 - The API Gateway makes a synchronous request to Lambda and waits for the response.
2 - Lambda initiates the execution of the asynchronous workflow
3 - After starting the workflow execution, it connects to AppSync and creates a channel to receive asynchronous notifications (channels are ephemeral and unlimited, in this case it can create one channel per request with the workflow execution ID)
4 - The workflow is executed asynchronously, calling other workflows.
5 - Upon completion of the main workflow, it makes a Post to the AppSync events API with the processing result, the post is made to the channel that was created by Lambda using the workflow execution ID
6 - AppSync receives the Post and sends a notification to the subscriber, which in this case is Lambda
7 - Lambda receives the message asynchronously, verifies if it was successful and if positive, closes the websocket connection with AppSync
8 - Lambda sends the response to the API Gateway that was waiting for the synchronous response.
