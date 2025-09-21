# Fichier: terraform/sqs_lambda.tf


resource "aws_sqs_queue" "events_queue" {
  name                       = "${local.project_name}-events-queue"
  visibility_timeout_seconds = 360
  tags = { Project = local.project_name }
}
resource "aws_iam_role" "lambda_parquet_converter_role" {
  name               = "${local.project_name}-lambda-parquet-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}
resource "aws_iam_policy" "lambda_parquet_converter_policy" {
  name        = "${local.project_name}-lambda-parquet-policy"
  description = "Allows Lambda to read from SQS and write to S3"
  policy      = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"], Resource = aws_sqs_queue.events_queue.arn },
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = ["s3:PutObject"], Resource = "${aws_s3_bucket.data_lake.arn}/*" }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_parquet_converter_role.name
  policy_arn = aws_iam_policy.lambda_parquet_converter_policy.arn
}

# 5. La fonction Lambda, créée avec un code factice. CodeBuild la mettra à jour.
resource "aws_lambda_function" "parquet_converter" {
  # --- MODIFICATION CRUCIALE ---
  # On fournit un fichier .zip factice pour satisfaire la validation de Terraform
  filename      = "../lambda_converter/dummy_package.zip"
  package_type  = "Zip"
  handler       = "index.handler" 
  runtime       = "python3.12"
  # ----------------------------
  
  function_name = "${local.project_name}-parquet-converter"
  role          = aws_iam_role.lambda_parquet_converter_role.arn
  timeout       = 120
  memory_size   = 512

  environment {
    variables = { S3_BUCKET_NAME = aws_s3_bucket.data_lake.bucket }
  }
}

# 9. Le branchement SQS -> Lambda (inchangé)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn                 = aws_sqs_queue.events_queue.arn
  function_name                    = aws_lambda_function.parquet_converter.arn
  batch_size                       = 100
  maximum_batching_window_in_seconds = 10
}