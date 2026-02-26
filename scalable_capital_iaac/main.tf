provider "aws" {
  region = var.region
}


# ============ SQS queue =============== #
resource "aws_sqs_queue" "order_queue" {
  name = "order-queue"
}


# ============= roles & policies =============== #
# IAM Role for Lambdas
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_policy" "sqs_access" {
  name = "lambda_sqs_access"


  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.order_queue.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_sqs_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.sqs_access.arn
}


# ============= Lambda function =============== #
# Lambda - AddOrder : here we package the Lambda function in a zip format as part of aws requirments
data "archive_file" "add_order_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/add_order.py"
  output_path = "${path.module}/lambda/add_order.zip"
}


resource "aws_lambda_function" "add_order" {
  function_name = "AddOrder"
  handler       = "add_order.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.add_order_zip.output_path
  source_code_hash = data.archive_file.add_order_zip.output_base64sha256

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.order_queue.id
    }
  }
}

# Lambda - ProcessOrder
data "archive_file" "process_order_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/process_order.py"
  output_path = "${path.module}/lambda/process_order.zip"
}


resource "aws_lambda_function" "process_order" {
  function_name = "ProcessOrder"
  handler       = "process_order.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.lambda_role.arn
  filename      = data.archive_file.process_order_zip.output_path
  source_code_hash = data.archive_file.process_order_zip.output_base64sha256
}


# ================== # SQS Trigger for ProcessOrder ================ #
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.order_queue.arn
  function_name    = aws_lambda_function.process_order.arn
  batch_size       = 1
}

# ================= # API Gateway REST ==================== #
resource "aws_apigatewayv2_api" "orders_api" {
  name          = "orders-api"
  protocol_type = "HTTP"
}


resource "aws_apigatewayv2_integration" "add_order_integration" {
  api_id           = aws_apigatewayv2_api.orders_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.add_order.invoke_arn
  integration_method = "POST"
}


resource "aws_apigatewayv2_route" "post_orders" {
  api_id    = aws_apigatewayv2_api.orders_api.id
  route_key = "POST /orders"
  target    = "integrations/${aws_apigatewayv2_integration.add_order_integration.id}"
}


resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.orders_api.id
  name        = "$default"
  auto_deploy = true
}


resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.add_order.function_name
  principal     = "apigateway.amazonaws.com"
}
