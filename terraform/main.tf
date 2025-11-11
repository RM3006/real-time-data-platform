# File: terraform/main.tf

# 1. Configure the AWS Provider
# Specifies that we are building resources on AWS
# and sets the default region for all resources.
provider "aws" {
  region = "eu-west-3" # Paris
}

# 2. Define Local Variables
# Creates a reusable variable for the project name to ensure
# consistent naming across all resources.
locals {
  project_name = "realtime-platform"
}

# 3. Resource: S3 Bucket (The Data Lake)
# Creates the central S3 bucket that will serve as our Data Lake,
# storing all incoming raw and processed data.
resource "aws_s3_bucket" "data_lake" {
  # The bucket name must be globally unique. We append a random
  # string to our project name to ensure this.
  bucket = "${local.project_name}-data-lake-${random_string.bucket_suffix.result}"

  # Allows the bucket to be destroyed even if it contains objects.
  # This is useful for development but should be disabled in production.
  force_destroy = true

  tags = {
    Project = local.project_name
  }
}

# 4. Resource: S3 Bucket Versioning
# Manages the versioning configuration for our S3 bucket.
resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  # Link to the S3 bucket created above.
  bucket = aws_s3_bucket.data_lake.id

  # Enable versioning to protect against accidental overwrites or deletions.
  versioning_configuration {
    status = "Enabled"
  }
}

# 5. Utility: Random String Generator
# Creates a random 8-character string to append to the S3 bucket
# name, ensuring it is always globally unique.
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

# 6. Output: Data Lake Bucket Name
# Makes the auto-generated S3 bucket name available as an output
# after running 'terraform apply'. We use this in other scripts.
output "data_lake_bucket_name" {
  description = "The name of the S3 bucket created for the data lake."
  value       = aws_s3_bucket.data_lake.bucket
}

# 7. Output: ECR Repository URL
# Makes the ECR repository URL available as an output.
# This is used in our Docker build/push commands.
output "ecr_repository_url" {
  description = "The URL of the ECR repository for the Lambda container image."
  # This value is derived from the 'aws_ecr_repository' resource
  # defined in another file (e.g., codebuild.tf or ecr.tf).
  value       = aws_ecr_repository.lambda_converter_repo.repository_url
}