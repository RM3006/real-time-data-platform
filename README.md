# real-time-data-platform

Personal repo dedicated to data project "Real Time Behavioral Analysis", built with Gemini 2.5 Pro

This project constructs a robust, cloud-native platform designed to ingest, process, and prepare a high-velocity stream of user behavioral data for analysis, mirroring architectures used in major tech companies.

1. Defining the Cloud Foundation (Infrastructure as Code)

To ensure our cloud setup is repeatable, version-controlled, and reliably deployed, we defined all the necessary AWS resources using Terraform (Infrastructure as Code). Instead of clicking around in the AWS console, we wrote descriptive code.

What we built:

S3 Data Lake (main.tf): A central, durable storage bucket (realtime-platform-data-lake-...) to hold our processed data, configured with versioning enabled for safety.

SQS Queue (sqs_lambda.tf): A message queue (realtime-platform-events-queue) acts as a reliable buffer, receiving raw events and ensuring no data is lost even if downstream processing is slow.

ECR Repository (codebuild.tf): A private Docker image registry (realtime-platform-converter-repo) to store the code for our processing function.

IAM Roles & Policies (sqs_lambda.tf, codebuild.tf): Specific security roles were created for our Lambda function and our build process, granting them only the minimum permissions needed (e.g., read from SQS, write to S3, push to ECR).

Lambda Function Placeholder (sqs_lambda.tf): We initially created the Lambda function definition (realtime-platform-parquet-converter) using a minimal dummy code package (dummy_package.zip).

CodeBuild Project (codebuild.tf): An automated build service (realtime-platform-image-builder) configured to fetch code from S3, build our Docker image, and deploy it.

Key Files: All definitions are located in the /terraform directory.


2. Simulating the Data Stream (The Producer)

To feed our platform, we needed a source of continuous data. We created a Python script that simulates user events (page views, clicks, etc.). To make this script easy to run anywhere without worrying about installing Python or dependencies, we packaged it into a Docker container.

How it works: The Dockerfile in the /producer directory contains instructions to build an image (realtime-producer:v1). This image bundles the Python script (generate_events.py) and its required library (boto3, listed in requirements.txt).

Running it: We launch this container using docker run. It starts generating JSON events and sends them directly to our SQS queue in AWS.

Key Files: Located in the /producer directory.


3. Processing Events: The Lambda Converter

This is where the core data transformation happens in real-time. We needed a component that could: a) Automatically pick up messages from the SQS queue. b) Handle potentially large Python libraries (pandas, pyarrow) needed for data manipulation. c) Convert the incoming JSON data into the efficient Parquet format. d) Write the resulting Parquet files to our S3 Data Lake, partitioned by date.

An AWS Lambda function deployed as a Docker container image was the perfect solution.

The Code: The logic resides in parquet_converter.py within the /lambda_converter directory. It reads batches of messages from SQS, uses Pandas/PyArrow for conversion, and writes to S3.

The Deployment Challenge: Because pandas and pyarrow are large and need Linux-compatible versions, we couldn't deploy this as a simple .zip file. We defined a specific Dockerfile.lambda (at the project root) to build a compatible container image.

Key Files: /lambda_converter/parquet_converter.py, /lambda_converter/requirements.txt, Dockerfile.lambda.


4. Building & Deploying the Lambda Automatically (CodeBuild)

Manually building the Lambda's Docker image and updating the function proved complex and error-prone (especially with cross-platform compatibility issues). We automated this using AWS CodeBuild.

How it works:

We package our entire project source code (including the Dockerfile.lambda and the Lambda code itself) into a source.zip file.

We upload this source.zip to our S3 bucket.

We manually trigger the CodeBuild project (aws codebuild start-build).

CodeBuild reads instructions from the buildspec.yml file (at the project root).

It downloads source.zip, builds the Docker image inside a compatible AWS environment, pushes the image to ECR, and finally updates the Lambda function to use this new, correct image.

Key Files: buildspec.yml, /terraform/codebuild.tf.


Summary steps 1 to 4
The Docker producer sends JSON events to SQS, Lambda processes them into Parquet files in S3, and the infrastructure is managed by Terraform. The Lambda deployment process is handled reliably by CodeBuild, triggered manually via an S3 upload. The next major step is configuring Snowflake (Snowpipe, dbt transformations) to consume and analyze this data.
