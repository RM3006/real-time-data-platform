# File: terraform/sqs_lambda.tf
# Defines the SQS queue, the Lambda function, and the permissions that connect them.

# 1. SQS Queue: The reliable buffer for incoming raw events.
resource "aws_sqs_queue" "events_queue" {
  name                       = "${local.project_name}-events-queue"
  # Set high visibility timeout to give the Lambda (120s) ample time to process
  # and delete the message batch. 360s = 6 minutes.
  visibility_timeout_seconds = 360
  tags                       = { Project = local.project_name }
}

# 2. Lambda IAM Role: Defines the identity our Lambda function will assume.
resource "aws_iam_role" "lambda_parquet_converter_role" {
  name               = "${local.project_name}-lambda-parquet-role"
  # This "Trust Policy" allows the AWS Lambda service to assume this role.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

# 3. Lambda IAM Policy: Spells out the exact permissions for the Lambda role.
resource "aws_iam_policy" "lambda_parquet_converter_policy" {
  name        = "${local.project_name}-lambda-parquet-policy"
  description = "Allows Lambda to read from SQS and write to S3"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      # 1. Allow reading/deleting messages from our specific SQS queue.
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.events_queue.arn },
      # 2. Allow writing logs to CloudWatch for debugging.
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      # 3. Allow writing Parquet files to our S3 Data Lake.
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.data_lake.arn}/*" }
    ]
  })
}

# 4. Policy Attachment: Connects the policy (permissions) to the role (identity).
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_parquet_converter_role.name
  policy_arn = aws_iam_policy.lambda_parquet_converter_policy.arn
}

# 5. The Lambda Function
# This function is defined to run as a Docker Image.
# Its code is deployed by our CodeBuild pipeline, which updates the :latest tag.
resource "aws_lambda_function" "parquet_converter" {


  package_type  = "Image"
  function_name = "${local.project_name}-parquet-converter"
  role          = aws_iam_role.lambda_parquet_converter_role.arn
  timeout       = 120
  memory_size   = 512

  # Points to the image in ECR that our CodeBuild pipeline builds and pushes.
  image_uri     = "${aws_ecr_repository.lambda_converter_repo.repository_url}:latest"

  environment {
    variables = { S3_BUCKET_NAME = aws_s3_bucket.data_lake.bucket }
  }
}

# 6. SQS Event Source Mapping
# This resource "plugs" the SQS queue into the Lambda function.
# It tells Lambda to invoke our function with batches of 100 messages
# or after 10 seconds, whichever comes first.
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                 = aws_sqs_queue.events_queue.arn
  function_name                    = aws_lambda_function.parquet_converter.arn
  batch_size                       = 100
  maximum_batching_window_in_seconds = 10
}