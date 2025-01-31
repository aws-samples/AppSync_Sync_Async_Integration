import boto3
from botocore.exceptions import ClientError
import os
import logging
import json

# Configure logging
logger = logging.getLogger()
logger.setLevel("INFO")

def get_secret():

    secret_name = os.environ["API_KEY"]
    region_name = "us-east-1"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )

        secret = get_secret_value_response['SecretString']

        return secret
    except ClientError as e:
        raise e

    

    # Your code goes here.
