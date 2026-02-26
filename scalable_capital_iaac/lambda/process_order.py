import os
import boto3
import json
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """ Process an order function """
    for record in event['Records']:
        print("Received event:", event)
        try:
            body = json.loads(record['body'])
            if isinstance(body, str):
                logging.info("Received body is a string")
                continue
            order_id = body['id']
            if not order_id:
                logging.warning("Order ID is missing in the message body")
                continue
            logging.info("Processing order with ID: %s", order_id)
            logging.info("Order %s processed successfully", order_id)
        except Exception as e:
            logging.error("Error processing order: %s", e)

    return {
        'status':'ok'
    }
