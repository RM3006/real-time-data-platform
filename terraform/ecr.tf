# Fichier: terraform/ecr.tf
resource "aws_ecr_repository" "lambda_converter_repo" {
  name = "${local.project_name}-converter-repo"
  force_delete = true
}