# File: terraform/codebuild.tf
# Defines the ECR repository, the CodeBuild project, and all related IAM roles/policies.

# --- ECR (Elastic Container Registry) ---

# 1. The ECR repository where our final Lambda Docker image will be stored.
resource "aws_ecr_repository" "lambda_converter_repo" {
  name         = "${local.project_name}-converter-repo"
  # Allows the repository to be deleted even if it contains images.
  # Useful for development, but should be disabled in production.
  force_delete = true
}

# --- IAM (Identity and Access Management) for CodeBuild ---

# 2. The IAM Role that the CodeBuild project will assume.
resource "aws_iam_role" "codebuild_role" {
  name = "${local.project_name}-codebuild-role"
  # This trust policy allows the CodeBuild service to assume this role.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" } }]
  })
}

# 3. The main IAM Policy defining what the CodeBuild role can do.
resource "aws_iam_policy" "codebuild_policy" {
  name = "${local.project_name}-codebuild-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # 3a. Allow writing logs to CloudWatch.
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "*" },
      
      # 3b. --- ECR PERMISSIONS SPLIT ---
      # Permission for GetAuthorizationToken (MUST use Resource: "*").
      {
        Effect   = "Allow",
        Action   = "ecr:GetAuthorizationToken",
        Resource = "*"
      },
      # Permissions to push the built image to our specific ECR repository.
      {
        Effect = "Allow",
        Action = [
          "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"
        ],
        Resource = aws_ecr_repository.lambda_converter_repo.arn
      },
      
      # 3c. Permissions for CodeBuild to download the source.zip from S3.
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

# 4. A separate IAM Policy to allow CodeBuild to update the Lambda function.
resource "aws_iam_policy" "codebuild_lambda_update_policy" {
  name   = "${local.project_name}-codebuild-lambda-update-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = "lambda:UpdateFunctionCode",
      # This resource is defined in sqs_lambda.tf
      Resource = aws_lambda_function.parquet_converter.arn
    }]
  })
}

# 5. Attaches the main policy to the CodeBuild role.
resource "aws_iam_role_policy_attachment" "codebuild_ecr_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# 6. Attaches the Lambda update policy to the CodeBuild role.
resource "aws_iam_role_policy_attachment" "codebuild_lambda_update_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_lambda_update_policy.arn
}


# --- CodeBuild Project Definition ---

# 7. The CodeBuild project itself.
resource "aws_codebuild_project" "image_builder" {
  name          = "${local.project_name}-image-builder"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = "15" # Set build timeout to 15 minutes

  artifacts { type = "NO_ARTIFACTS" } # We are pushing a Docker image, not storing artifacts

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    # Use a standard Amazon Linux 2 image with Docker capabilities
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    # Privileged mode is required to build Docker images inside a Docker container
    privileged_mode = true

    # Pass environment variables to the buildspec.yml script
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
      value = "${local.project_name}-parquet-converter"
    }
    environment_variable {
      name  = "S3_BUCKET_NAME"
      value = aws_s3_bucket.data_lake.id
    }
  }

  # Define the source as "NO_SOURCE" because we will manually
  # download the source.zip from S3 in the buildspec.
source {
    type = "NO_SOURCE"
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
            - echo "Attempting to update Lambda function..."
            # This command will try to update the function.
            # If it fails (because the function doesn't exist yet),
            # the '|| true' will "swallow" the error and allow the build to succeed.
            - aws lambda update-function-code --function-name $LAMBDA_FUNCTION_NAME --image-uri $IMAGE_REPO_URI:$IMAGE_TAG || true
            
    EOF
  }

  # Ensures the S3 bucket versioning is applied before this project is created.
  depends_on = [aws_s3_bucket_versioning.data_lake_versioning]
}

# 8. Data source to get the current AWS Account ID dynamically.
data "aws_caller_identity" "current" {}