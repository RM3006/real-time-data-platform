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






# Real-Time Behavioral Data Platform (Portfolio Project)

This project constructs a robust, cloud-native platform designed to ingest, process, and prepare a high-velocity stream of user behavioral data for analysis.

The entire system is automated, from infrastructure provisioning with Terraform to data transformation orchestration with Airflow.

Key Features

 Real-Time Ingestion: Captures and processes data with end-to-end latency in seconds.
 Infrastructure as Code (IaC): All AWS infrastructure (S3, SQS, IAM, ECR, CodeBuild, Lambda) is defined and managed using Terraform for full reproducibility.
 Scalable & Serverless: Built on AWS SQS and Lambda to automatically handle any volume of data, from a few events per second to millions.
 Optimized Storage: Uses S3 as a Data Lake, converting raw JSON into date-partitioned Parquet files for massive cost and performance gains.
 Automated Data Modeling: Uses dbt Core for complex, testable, and version-controlled data transformations, including advanced sessionization logic.
 Production-Grade Orchestration: Employs Apache Airflow (via Docker Compose) to schedule and monitor the entire dbt transformation pipeline.
 CI/CD for Data: Features an automated build pipeline using AWS CodeBuild to reliably build and deploy the Lambda function's Docker image, solving complex dependency and architecture issues.

Tech Stack

Infrastructure : Terraform : Infrastructure as Code (IaC) for all AWS resources.
Cloud Platform : AWS : S3 (Data Lake), SQS (Queue), Lambda (Processing), ECR (Image Registry), CodeBuild (CI/CD)
Containerization : Docker : Packaging the data producer & the Lambda function.
Data Warehouse : Snowflake : Cloud data platform for storage and analytics.
Ingestion : Snowpipe : Continuous, automated loading from S3 to Snowflake.
Transformation : dbt Core : Data modeling, testing, and sessionization.
Orchestration : Apache Airflow : Scheduling and monitoring the dbt pipeline.

---

Architecture Diagram


The drawn out Diagram can be found here : (`real-time-data-platform\Documentation\images\Realtime_Data_Platform_Diagram.png`)

---

Project Steps & Components

Here is a step-by-step breakdown of how the platform is built and how data flows through it.

1. Defining the Cloud Foundation (Infrastructure as Code)

To ensure the cloud setup is repeatable and version-controlled, all necessary AWS resources are defined using Terraform.

 S3 Data Lake (`main.tf`): A central, durable storage bucket (`realtime-platform-data-lake-...`) to hold our processed Parquet files, configured with versioning enabled.
 SQS Queue (`sqs_lambda.tf`): A message queue (`realtime-platform-events-queue`) that acts as a reliable buffer, receiving raw events and ensuring no data is lost.
 ECR Repository (`codebuild.tf`): A private Docker image registry (`realtime-platform-converter-repo`) to store the code for our processing function.
 IAM Roles & Policies (`sqs_lambda.tf`, `codebuild.tf`): Specific security roles for Lambda and CodeBuild, granting only the minimum permissions needed (e.g., read from SQS, write to S3, push to ECR).
 Lambda Function Placeholder (`sqs_lambda.tf`): An initial "dummy" Lambda function definition, which will be overwritten by our CodeBuild process.
 CodeBuild Project (`codebuild.tf`): An automated build service (`realtime-platform-image-builder`) configured to fetch code from S3, build our Docker image, and deploy it.
 Key Files: All definitions are located in the `/terraform` directory.

2. Simulating the Data Stream (The Producer)

To feed our platform, a Python script simulates a continuous stream of user events (page views, clicks, etc.). This script is packaged into a Docker container for consistency and portability.

 How it works: The `Dockerfile` in the `/producer` directory builds an image (`realtime-producer:v1`). This image bundles the Python script (`generate_events.py`) and its `boto3` dependency.
 Running it: The container is launched using `docker run`. It starts generating JSON events and sends them directly to the SQS queue in AWS.
 Key Files: Located in the `/producer` directory.

3. Processing Events (The Lambda Converter)

This is where the core real-time transformation happens. This component automatically picks up messages from SQS, converts the JSON data into the efficient Parquet format, and writes the resulting files to our S3 Data Lake, partitioned by date.

 The Code: The logic resides in `parquet_converter.py` within the `/lambda_converter` directory.
 The Deployment Challenge: Because `pandas` and `pyarrow` are large and have C-based dependencies, they cannot be deployed as a simple `.zip` file. We defined a specific `Dockerfile.lambda` (at the project root) to build a Linux-compatible container image for the function.
 Key Files: `/lambda_converter/parquet_converter.py`, `Dockerfile.lambda`.

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

 How it works: A `STORAGE INTEGRATION` provides secure, keyless access to S3. An `REALTIME_DATA_EVENTS_PARQUET` points to the `realtime_data_platform_events/raw_data_events/` folder in S3. A `PIPE` (`REALTIME_EVENTS_PIPE`) automatically detects new Parquet files created by our Lambda and ingests them into the `RAW_REALTIME_DATA_EVENTS` table.
 Key Files: The SQL definitions for these objects are managed in Snowflake, but they target the `REALTIME_DATA_PLATFORM_DB.RAW.RAW_REALTIME_DATA_EVENTS` table.

6. Data Modeling & Transformation (dbt Core)

This is the analytics engineering hub of the project. We use dbt Core to transform the raw, messy data into clean, reliable, and insightful models.

 How it works:
    1.  Seeds: We load static lookup tables (`products.csv`, `users.csv`) into Snowflake using `dbt seed`.
    2.  Staging: `stg_events.sql` cleans, de-duplicates, and tests the raw data from `RAW_REALTIME_DATA_EVENTS`.
    3.  Intermediate: `int_events_sessionized.sql` applies complex window functions to group individual events into user sessions (sessionization).
    4.  Marts: `fact_sessions.sql` aggregates the session data and joins it with user information to create a final, performant table for analysts.
 Key Files: All transformation logic is located in the `/data_transformations` directory.

7. Pipeline Orchestration (Apache Airflow)

To run our dbt transformations on a reliable, automated schedule, we use Apache Airflow.

 How it works: We run Airflow locally using `docker-compose`. A DAG (workflow) file defines our pipeline. This DAG runs our dbt commands in the correct order (`dbt seed`, then `dbt run`, then `dbt test`) on a daily schedule.
 Key Files: The `/airflow` directory contains the `docker-compose.yaml` to launch Airflow and the `dags/dbt_workflow_dag.py` file which defines the workflow.

---

How to Run This Project

This project requires a two-phase deployment: Infrastructure (Terraform) and Application (CodeBuild/Docker).

Phase 1: Deploy Infrastructure

1.  Configure AWS & Terraform: Ensure you have the AWS CLI and Terraform installed. Run `aws configure` with your credentials.
2.  Initialize Terraform: `cd terraform` and run `terraform init`.
3.  Deploy Infrastructure: Run `terraform apply`. This will create S3, SQS, ECR, and the placeholder Lambda function.

Phase 2: Deploy Lambda Code (via CodeBuild)

1.  Package Source: At the project root, create a `source.zip` file containing all project files (except `.git`, `.terraform`, etc.).
2.  Upload to S3: Upload the package to the correct path:
    `aws s3 cp ./source.zip s3://YOUR_BUCKET_NAME/realtime_data_platform_events/source.zip`
3.  Start Build: Manually trigger CodeBuild to build and deploy the Lambda:
    `aws codebuild start-build --project-name realtime-platform-image-builder`

Phase 3: Run the Pipeline

1.  Start Producer: Run the Docker producer to generate data:
    `docker run --rm -v ${HOME}/.aws:/root/.aws realtime-producer:v1`
2.  Verify Ingestion: Check your `RAW_REALTIME_DATA_EVENTS` table in Snowflake. Data should arrive via Snowpipe.
3.  Start Airflow: `cd airflow` and run `docker compose up -d`.
4.  Run dbt Workflow: Go to `http://localhost:8080`, log in, and trigger the `dbt_realtime_platform_workflow` DAG.
5.  Check Results: Query your final `FACT_SESSIONS` table in Snowflake.

---

Data Models & Documentation

This project uses dbt to transform raw events into analytics-ready tables. The full documentation for the data models, including column descriptions and a complete data lineage graph, can be viewed by:

1.  Navigating to the `data_transformations` directory and activating the environment (`.\dbt_env\Scripts\activate`).
2.  Running `dbt docs generate --target realtime_db_target`.
3.  Running `dbt docs serve` to open the interactive website locally.