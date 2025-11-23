# Real-Time Behavioral Data Platform (Portfolio Project)

This project constructs a robust, cloud-native platform designed to ingest, process, and prepare a high-velocity stream of user behavioral data for analysis.

The entire system is automated, from infrastructure provisioning with Terraform to data transformation orchestration with Airflow.


---


Key Features

1. Real-Time Ingestion: Captures and processes data with end-to-end latency in seconds.
2. Infrastructure as Code (IaC): All AWS infrastructure (S3, SQS, IAM, ECR, CodeBuild, Lambda) is defined and managed using Terraform for full reproducibility.
3. Scalable & Serverless: Built on AWS SQS and Lambda to automatically handle any volume of data, from a few events per second to millions.
4. Optimized Storage: Uses S3 as a Data Lake, converting raw JSON into date-partitioned Parquet files for massive cost and performance gains.
5. Automated Data Modeling: Uses dbt Core for complex, testable, and version-controlled data transformations, including advanced sessionization logic.
6. Production-Grade Orchestration: Employs Apache Airflow (via Docker Compose) to schedule and monitor the entire dbt transformation pipeline.
7. CI/CD for Data: Features an automated build pipeline using AWS CodeBuild to reliably build and deploy the Lambda function's Docker image, solving complex dependency and architecture issues.


Tech Stack

1. Infrastructure : Terraform : Infrastructure as Code (IaC) for all AWS resources.
2. Cloud Platform : AWS : S3 (Data Lake), SQS (Queue), Lambda (Processing), ECR (Image Registry), CodeBuild (CI/CD)
3. Containerization : Docker : Packaging the data producer & the Lambda function.
4. Data Warehouse : Snowflake : Cloud data platform for storage and analytics.
5. Ingestion : Snowpipe : Continuous, automated loading from S3 to Snowflake.
6. Transformation : dbt Core : Data modeling, testing, and sessionization.
7. Orchestration : Apache Airflow : Scheduling and monitoring the dbt pipeline.


---


Architecture Diagram


The drawn out Diagram can be found here : (`real-time-data-platform\documentation\Architecture\Realtime_Data_Platform_Diagram.png`)


---

Project Steps & Components

Here is a step-by-step breakdown of how the platform is built and how data flows through it.

1. Defining the Cloud Foundation (Infrastructure as Code)

To ensure the cloud setup is repeatable and version-controlled, all necessary AWS resources are defined using Terraform.

1. S3 Data Lake (`main.tf`): A central, durable storage bucket (`realtime-platform-data-lake-...`) to hold our processed Parquet files, configured with versioning enabled.
2. SQS Queue (`sqs_lambda.tf`): A message queue (`realtime-platform-events-queue`) that acts as a reliable buffer, receiving raw events and ensuring no data is lost.
3. ECR Repository (`codebuild.tf`): A private Docker image registry (`realtime-platform-converter-repo`) to store the code for our processing function.
4. IAM Roles & Policies (`sqs_lambda.tf`, `codebuild.tf`): Specific security roles for Lambda and CodeBuild, granting only the minimum permissions needed (e.g., read from SQS, write to S3, push to ECR).
5. Lambda Function Placeholder (`sqs_lambda.tf`): An initial "dummy" Lambda function definition, which will be overwritten by our CodeBuild process.
6. CodeBuild Project (`codebuild.tf`): An automated build service (`realtime-platform-image-builder`) configured to fetch code from S3, build our Docker image, and deploy it.
7. Key Files: All definitions are located in the `/terraform` directory.


2. Simulating the Data Stream (The Producer)

To feed our platform, a Python script simulates a continuous stream of user events (page views, clicks, etc.). This script is packaged into a Docker container for consistency and portability.

1. How it works: The `Dockerfile` in the `/producer` directory builds an image (`realtime-producer:v1`). This image bundles the Python script (`generate_events.py`) and its `boto3` dependency.
2. Running it: The container is launched using `docker run`. It starts generating JSON events and sends them directly to the SQS queue in AWS.
3. Key Files: Located in the `/producer` directory.


3. Processing Events (The Lambda Converter)

This is where the core real-time transformation happens. This component automatically picks up messages from SQS, converts the JSON data into the efficient Parquet format, and writes the resulting files to our S3 Data Lake, partitioned by date.

1. The Code: The logic resides in `parquet_converter.py` within the `/lambda_converter` directory.
2. The Deployment Challenge: Because `pandas` and `pyarrow` are large and have C-based dependencies, they cannot be deployed as a simple `.zip` file. We defined a specific `Dockerfile.lambda` (at the project root) to build a Linux-compatible container image for the function.
3. Key Files: `/lambda_converter/parquet_converter.py`, `Dockerfile.lambda`.


4. Building & Deploying the Lambda Automatically (CodeBuild)

To solve the complex and error-prone manual Docker build process, we automated it using AWS CodeBuild.

 How it works:
1.  We package our entire project source code (including `Dockerfile.lambda` and the Lambda code) into a `source.zip` file.
2.  We upload this `source.zip` to a specific folder in our S3 bucket.
3.  We manually trigger the CodeBuild project (`aws codebuild start-build`).
4.  CodeBuild reads instructions from the `buildspec.yml` file, downloads the `source.zip`, builds the Docker image in a compatible cloud environment, pushes the image to ECR, and finally updates the Lambda function to use this new, correct image.

Key Files: `buildspec.yml`, `/terraform/codebuild.tf`.


5. Automated Ingestion into Snowflake (Snowpipe)

This step bridges our S3 Data Lake to our Snowflake Data Warehouse.

 How it works:
1. A `STORAGE INTEGRATION` provides secure, keyless access to S3. An `REALTIME_DATA_EVENTS_PARQUET` points to the `realtime_data_platform_events/raw_data_events/` folder in S3. A `PIPE` (`REALTIME_EVENTS_PIPE`) automatically detects new Parquet files created by our Lambda and ingests them into the `RAW_REALTIME_DATA_EVENTS` table.

Key Files: The SQL definitions for these objects are managed in Snowflake, but they target the `REALTIME_DATA_PLATFORM_DB.RAW.RAW_REALTIME_DATA_EVENTS` table.


6. Data Modeling & Transformation (dbt Core)

This is the analytics engineering hub of the project. We use dbt Core to transform the raw, messy data into clean, reliable, and insightful models.

 How it works:
1. Seeds: We load static lookup tables (`products.csv`, `users.csv`) into Snowflake using `dbt seed`.
2.  Staging: `stg_events.sql` cleans, de-duplicates, and tests the raw data from `RAW_REALTIME_DATA_EVENTS`.
3.  Intermediate: `int_events_sessionized.sql` applies complex window functions to group individual events into user sessions (sessionization).
4.  Marts: `fact_sessions.sql` aggregates the session data and joins it with user information to create a final, performant table for analysts.

Key Files: All transformation logic is located in the `/data_transformations` directory.


7. Pipeline Orchestration (Apache Airflow)

To run our dbt transformations on a reliable, automated schedule, we use Apache Airflow.

How it works:
1. We run Airflow locally using `docker-compose`. A DAG (workflow) file defines our pipeline. This DAG runs our dbt commands in the correct order (`dbt seed`, then `dbt run`, then `dbt test`) on a daily schedule.

Key Files: The `/airflow` directory contains the `docker-compose.yaml` to launch Airflow and the `dags/dbt_workflow_dag.py` file which defines the workflow.


---


How to Run This Project

This project uses a standard two-phase deployment pattern to manage the "chicken-and-egg" dependency between the infrastructure (Lambda) and the application (the Docker image).

Phase 1: Deploy Base Infrastructure (Terraform Apply #1)
This first step creates all the "scaffolding": the S3 bucket, SQS queue, IAM roles, ECR repository, and the CodeBuild project.

1. Configure AWS & Terraform: Ensure you have the AWS CLI and Terraform installed. Run aws configure with your credentials.
2. Initialize Terraform: cd terraform and run terraform init.
3. Run First Apply: Run terraform apply.
    Note: This command is expected to fail at the very end with an error like Source image ... does not exist. This is normal.
    Goal: This "failed" run successfully creates the aws_ecr_repository and aws_codebuild_project needed for the next phase.


Phase 2: Build & Push the Lambda Image (CodeBuild)
Now that the ECR repository and CodeBuild project exist, we build our application image.

1. Package Source: At the project root, create a source.zip file containing all project files (except .git, .terraform, etc.).
2. Upload to S3: Upload the package to the correct path : aws s3 cp ./source.zip s3://realtime-platform-data-lake-0xbdu2rf/realtime_data_platform_events/source.zip
3. Start Build: Manually trigger CodeBuild to build the image and push it to ECR: aws codebuild start-build --project-name realtime-platform-image-builder --source-version source.zip
4. Monitor: Go to the AWS CodeBuild console and wait for this build to succeed.


Phase 3: Finalize Infrastructure (Terraform Apply #2)
Now that our Docker image exists in ECR, we can run Terraform a second time to complete the deployment.

1. Run Second Apply: In your terraform directory, run terraform apply again.
    Goal: This time, Terraform will see that the ECR image exists. It will successfully create the aws_lambda_function and the aws_lambda_event_source_mapping that connect it to SQS.
    The command will finish with Apply complete!.


Phase 4: Run the Pipeline

1. Build the Docker image to get the latest version of the generate_events.py script. Run in the terminal :
    `docker build -t realtime-producer:v1 ./producer`
2.  Start Producer: Run the Docker producer to generate data:
    `docker run --rm -v ${HOME}/.aws:/root/.aws realtime-producer:v1`
3.  Verify Ingestion: Check your `RAW_REALTIME_DATA_EVENTS` table in Snowflake. Data should arrive via Snowpipe.
4.  Start Airflow: `cd airflow` and run `docker compose up -d`.
5.  Run dbt Workflow: Go to `http://localhost:8080`, log in, and trigger the `dbt_realtime_platform_workflow` DAG.
6.  Check Results: Query your final `FACT_SESSIONS` table in Snowflake.


---


Data Models & Documentation

This project uses dbt to transform raw events into analytics-ready tables. The full documentation for the data models, including column descriptions and a complete data lineage graph, can be viewed by:

1.  Navigating to the `data_transformations` directory and activating the environment (`.\dbt_env\Scripts\activate`).
2.  Running `dbt docs generate --target realtime_db_target`.
3.  Running `dbt docs serve` to open the interactive website locally.

The complete, interactive documentation for the dbt models, including column descriptions and a full data lineage graph, is automatically published and available to view live at the link below:
https://quiet-llama-25564c.netlify.app/