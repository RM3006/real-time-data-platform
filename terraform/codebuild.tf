# Fichier: terraform/codebuild.tf (version corrigée)

# ... (les ressources de rôle et de politique IAM ne changent pas) ...
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
      { Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage"
        ],
        Resource = aws_ecr_repository.lambda_converter_repo.arn
      }
    ]
  })
}
resource "aws_iam_policy" "codebuild_lambda_update_policy" {
  name   = "${local.project_name}-codebuild-lambda-update-policy"
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{ Effect = "Allow", Action = "lambda:UpdateFunctionCode", Resource = aws_lambda_function.parquet_converter.arn }]
  })
}
resource "aws_iam_role_policy_attachment" "codebuild_ecr_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}
resource "aws_iam_role_policy_attachment" "codebuild_lambda_update_attach" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_lambda_update_policy.arn
}

# --- BLOC MODIFIÉ ---
# 5. Définition du projet CodeBuild (SANS la configuration du webhook)
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
  }

  source {
    type      = "GITHUB"
    location  = "https://github.com/RM3006/real-time-data-platform.git" 
    buildspec = "buildspec.yml"
  }
}


# 7. Data source pour récupérer l'ID du compte
data "aws_caller_identity" "current" {}