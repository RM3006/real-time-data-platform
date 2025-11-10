from __future__ import annotations
import pendulum
from airflow.models.dag import DAG
from airflow.operators.bash import BashOperator

# Define the absolute path to your dbt project *inside* the Airflow containers.
# We'll set this up in the next step.
DBT_PROJECT_DIR = "/opt/airflow/dbt/data_transformations"
# Define the path to your dbt profiles directory
DBT_PROFILES_DIR = "/opt/airflow/dbt_profiles"

with DAG(
    dag_id="dbt_realtime_platform_workflow",
    start_date=pendulum.datetime(2025, 1, 1, tz="Europe/Paris"),
    # This defines how often the workflow runs.
    schedule="30 2 * * 2",  # You can change this to "@hourly", "*/15 * * * *" (every 15 min), or None.
    catchup=False,
    doc_md="""
    ### dbt Workflow for the Real-Time Data Platform
    Orchestrates the daily run of dbt models:
    1. Loads static seed data.
    2. Runs all transformation models.
    3. Runs all data quality tests.
    """,
) as dag:

    # Task 1: Load CSV seeds into Snowflake
    dbt_seed_task = BashOperator(
        task_id="dbt_seed",
        # This command tells dbt where to find the project and the profiles
        bash_command=f"dbt seed --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR} --target realtime_db_target",
    )

    # Task 2: Run all dbt models
    dbt_run_task = BashOperator(
        task_id="dbt_run",
        bash_command=f"dbt run --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR} --target realtime_db_target",
    )

    # Task 3: Test all dbt models
    dbt_test_task = BashOperator(
        task_id="dbt_test",
        bash_command=f"dbt test --project-dir {DBT_PROJECT_DIR} --profiles-dir {DBT_PROFILES_DIR} --target realtime_db_target",
    )

    # Define the order of operations: seed -> run -> test
    dbt_seed_task >> dbt_run_task >> dbt_test_task