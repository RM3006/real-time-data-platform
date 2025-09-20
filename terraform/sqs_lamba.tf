# Fichier: terraform/sqs_lambda.tf

# 1. La file d'attente SQS qui servira de buffer pour nos événements
resource "aws_sqs_queue" "events_queue" {
  name = "${local.project_name}-events-queue"

  tags = {
    Project = local.project_name
  }
}

# 2. Le rôle IAM que notre future fonction Lambda "endossera" pour avoir des permissions
resource "aws_iam_role" "lambda_parquet_converter_role" {
  name = "${local.project_name}-lambda-parquet-role"

  # Cette politique de confiance permet au service Lambda d'utiliser ce rôle
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 3. La politique de permissions attachée à ce rôle
resource "aws_iam_policy" "lambda_parquet_converter_policy" {
  name        = "${local.project_name}-lambda-parquet-policy"
  description = "Allows Lambda to read from SQS and write to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { # Permission de lire et supprimer les messages de la file SQS
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = aws_sqs_queue.events_queue.arn
      },
      { # Permission d'écrire des logs dans CloudWatch
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      { # Permission d'écrire les fichiers Parquet dans notre Data Lake S3
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.data_lake.arn}/*" # Notez qu'on réutilise le bucket S3 défini dans main.tf
      }
    ]
  })
}

# 4. Lier la politique au rôle
resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_parquet_converter_role.name
  policy_arn = aws_iam_policy.lambda_parquet_converter_policy.arn
}