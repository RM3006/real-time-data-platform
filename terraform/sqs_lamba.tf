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

# 5. La fonction Lambda, maintenant définie à partir d'une image Docker
resource "aws_lambda_function" "parquet_converter" {
  # On spécifie le type de paquet et le nom de la fonction
  package_type  = "Image"
  function_name = "${local.project_name}-parquet-converter"
  role          = aws_iam_role.lambda_parquet_converter_role.arn
  
  # On augmente les ressources, car les conteneurs sont plus exigeants
  timeout     = 120 # 2 minutes
  memory_size = 512 # 512 MB

  # Le champ le plus important : l'URI de l'image. 
  # Il sera rempli à l'étape suivante, pour l'instant on met une valeur temporaire.
  image_uri = "${aws_ecr_repository.lambda_converter_repo.repository_url}:latest"

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