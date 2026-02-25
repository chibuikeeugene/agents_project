import os
import boto3
from loguru import logger
import json


def lambda_handler(event, context):
    """ Process an order function """
    for record in event['Records']:
        body = json.load(record['body'])
        order_id = body['id']
        logger.info(f"Processing order with ID: {order_id}")
        logger.info(f"Order {order_id} processed successfully")

    return {
        'status':'ok'
    }
