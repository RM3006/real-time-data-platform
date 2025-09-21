# Indique à Terraform que nous allons travailler avec AWS
provider "aws" {
  region = "eu-west-3"
}

# Définit un nom de base pour nos ressources pour éviter les conflits
locals {
  project_name = "realtime-platform"
}

# Ressource 1 : Le bucket S3 qui servira de Data Lake
resource "aws_s3_bucket" "data_lake" {
  bucket = "${local.project_name}-data-lake-${random_string.bucket_suffix.result}"
  force_destroy = true
  tags = {
    Project = local.project_name
  }
}

# Génère une chaîne aléatoire pour rendre le nom du bucket S3 unique
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

output "data_lake_bucket_name" {
  description = "The name of the S3 bucket created for the data lake."
  value       = aws_s3_bucket.data_lake.bucket
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository for the Lambda container image."
  value       = aws_ecr_repository.lambda_converter_repo.repository_url
}
