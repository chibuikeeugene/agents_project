import json
import boto3
import os

def lambda_handler(event, context):
    """ Add an order function """
    body = json.load(event['body'])
    order_id = body['id']

    # send the message via a queue
    # create a sqs client
    sqs_client = boto3.client("sqs", region_name=os.environ["AWS_REGION"])
    sqs_client.send_message(
        QueueUrl=os.environ["SQS_QUEUE_URL"],
        MessageBody=json.dumps({"order_id": order_id}),
    )

    # return a response message
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "Order added successfully", "order_id": order_id})
    }
