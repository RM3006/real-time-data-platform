from __future__ import annotations
import pendulum
from airflow.models.dag import DAG
from airflow.operators.bash import BashOperator

# Path to dbt project *inside* the Airflow containers.
DBT_PROJECT_DIR = "/opt/airflow/dbt/data_transformations"
# Path to dbt profiles directory
DBT_PROFILES_DIR = "/opt/airflow/dbt_profiles"

with DAG(
    dag_id="dbt_realtime_platform_workflow",
    start_date=pendulum.datetime(2025, 1, 1, tz="Europe/Paris"),
    # Schedule defines how often the dag will run. Currently, the dag is set to run every tuesday at 2:30 AM, Paris timezone.
    schedule="42 16 * * 2", 
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

    # Defining the order of the tasks within the dag: seed -> run -> test
    dbt_seed_task >> dbt_run_task >> dbt_test_task