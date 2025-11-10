# Start from the official Airflow image
FROM apache/airflow:3.1.2

# Switch to the ROOT user to install system packages
USER root

# Install git (which dbt needs)
RUN apt-get update && apt-get install -y git-core

# Switch back to the airflow user to install Python packages
USER airflow

# Install dbt-snowflake as the airflow user
RUN pip install --user dbt-snowflake