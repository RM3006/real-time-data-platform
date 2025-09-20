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
