\# Terraform Infrastructure for the Real-Time Data Platform



\## Overview



This directory contains the declarative Terraform configuration for the AWS infrastructure that powers the Real-Time Data Platform.



The infrastructure is managed entirely as code, adhering to the principles of \*\*Infrastructure as Code (IaC)\*\*. This approach ensures a reproducible, version-controlled, and automated deployment process, which eliminates manual configuration errors and enhances overall system reliability.



---



\## Architectural Components



The architecture is composed of several key AWS services, each selected for a specific and critical role within the data lifecycle.



\* \*\*S3 Bucket:\*\* At the core of the architecture lies the S3 bucket, which serves as the \*\*Data Lake\*\*. It is the central, durable repository for all processed data, structured to receive optimized Parquet files from the downstream processing layer.



\* \*\*SQS Queue:\*\* To ensure data durability and system resilience, an \*\*SQS (Simple Queue Service) queue\*\* is utilized as the primary ingestion buffer. This component decouples the data producer from the consumers, guaranteeing that events are not lost during periods of high traffic or downstream processing failures. It is a fundamental pattern for building robust, asynchronous systems.



\* \*\*ECR Repository:\*\* The data processing logic, along with its large dependencies, is deployed as a \*\*Docker container\*\*. The \*\*ECR (Elastic Container Registry)\*\* provides a secure, private, and versioned registry for this container image, making it readily available for the AWS Lambda service.



\* \*\*IAM Roles \& Policies:\*\* Security is managed through a set of fine-grained \*\*IAM Roles and Policies\*\*. The design adheres to the \*\*principle of least privilege\*\*, where each component, such as the Lambda function, is granted only the exact permissions required for its tasks (e.g., reading from SQS, writing to S3, and generating CloudWatch logs).



\* \*\*Lambda Function \& Event Source Mapping:\*\* The serverless \*\*AWS Lambda function\*\* is the compute engine of the ingestion pipeline. Deployed from the ECR image, it is capable of handling complex dependencies and transformations. The function is triggered by an \*\*Event Source Mapping\*\*, which efficiently polls the SQS queue and invokes the function with batches of messages, enabling scalable, event-driven processing.



---



\## Prerequisites



Before deploying this infrastructure, the following tools must be installed and configured on the local machine:



\* \*\*Terraform\*\* (v1.5.x or later)

\* \*\*AWS CLI\*\* (v2.x.x or later)

\* \*\*Configured AWS Credentials:\*\* The AWS CLI must be configured with valid user credentials via the `aws configure` command. The associated user or role requires sufficient permissions to create the resources listed above.



---



\## Deployment Instructions



The following instructions detail the standard Terraform workflow to provision and manage the infrastructure.



1\.  \*\*Navigate to this directory:\*\*

&nbsp;   ```bash

&nbsp;   cd terraform

&nbsp;   ```



2\.  \*\*Initialize Terraform:\*\*

&nbsp;   This command prepares the working directory and downloads the necessary provider plugins. It only needs to be run once per project setup.

&nbsp;   ```bash

&nbsp;   terraform init

&nbsp;   ```



3\.  \*\*Plan the deployment:\*\*

&nbsp;   This command creates an execution plan and provides a preview of the resources Terraform will create, change, or destroy. This step serves as a "dry run" to verify all changes before application.

&nbsp;   ```bash

&nbsp;   terraform plan

&nbsp;   ```



4\.  \*\*Apply the configuration:\*\*

&nbsp;   This command executes the plan and builds the infrastructure in the target AWS account. A final confirmation prompt will be displayed before any resources are provisioned.

&nbsp;   ```bash

&nbsp;   terraform apply

&nbsp;   ```

&nbsp;   When prompted, type `yes` to approve the plan.



---



\## Outputs



Upon successful application, Terraform provides key values from the created resources. These outputs are essential for configuring other parts of the platform.



View these outputs at any time by running:

```bash

terraform output

