# Fichier: terraform/codebuild.tf (Version finale et complète)

# Le dépôt ECR où notre image sera stockée
resource "aws_ecr_repository" "lambda_converter_repo" {
  name         = "${local.project_name}-converter-repo"
  force_delete = true
}

# 1. Rôle et Politiques IAM pour CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${local.project_name}-codebuild-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" } }]
  })
}
resource "aws_iam_policy" "codebuild_policy" {
  name = "${local.project_name}-codebuild-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      # --- ECR PERMISSIONS SPLIT ---
      { # Permission for GetAuthorizationToken (MUST use Resource: "*")
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*" 
      },
      { Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"
        ],
        Resource = aws_ecr_repository.lambda_converter_repo.arn
      },
      # Permissions nécessaires pour que CodeBuild puisse télécharger le code source depuis S3
      {
        Effect   = "Allow",
        Action   = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:ListBucket",
          "s3:ListBucketVersions"
        ],
        Resource = [
          aws_s3_bucket.data_lake.arn,
          "${aws_s3_bucket.data_lake.arn}/realtime_data_platform_events/source.zip"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_ecr_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}


# 2. Définition du projet CodeBuild
resource "aws_codebuild_project" "image_builder" {
  name          = "${local.project_name}-image-builder"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "15"

  artifacts { type = "NO_ARTIFACTS" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = "eu-west-3"
    }
    environment_variable {
      name  = "IMAGE_REPO_URI"
      value = aws_ecr_repository.lambda_converter_repo.repository_url
    }
    environment_variable {
      name  = "IMAGE_TAG"
      value = "latest"
    }
    environment_variable {
      name  = "LAMBDA_FUNCTION_NAME"
      value = aws_lambda_function.parquet_converter.function_name
    }
    environment_variable {
      name  = "S3_BUCKET_NAME"
      value = aws_s3_bucket.data_lake.id
    }
  }
  source {
    type      = "NO_SOURCE"
    # type      = "S3"
    #location  = "${aws_s3_bucket.data_lake.id}/realtime_data_platform_events/source.zip"
    buildspec = <<-EOF
      version: 0.2

      phases:
        install:
          runtime-versions:
            python: 3.12
        pre_build:
          commands:
            - echo "Downloading source code from S3..."
            - aws s3 cp s3://$S3_BUCKET_NAME/realtime_data_platform_events/source.zip .
            - echo "Unzipping source code..."
            - unzip source.zip
            - echo "Logging in to Amazon ECR..."
            - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
        build:
          commands:
            - echo "Build started on `date`"
            - echo "Building the Docker image..."
            - docker build -t $IMAGE_REPO_URI:$IMAGE_TAG -f Dockerfile.lambda .
        post_build:
          commands:
            - echo "Build completed on `date`"
            - echo "Pushing the Docker image to ECR..."
            - docker push $IMAGE_REPO_URI:$IMAGE_TAG
            - echo "Updating Lambda function..."
            - aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --image-uri $IMAGE_REPO_URI:$IMAGE_TAG
    EOF
  }
  depends_on = [aws_s3_bucket_versioning.data_lake_versioning]
}

# 4. Data source pour récupérer l'ID du compte
data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "codebuild_lambda_update_policy" {
  name   = "${local.project_name}-codebuild-lambda-update-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "lambda:UpdateFunctionCode",
      Resource = aws_lambda_function.parquet_converter.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_lambda_update_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_lambda_update_policy.arn
}