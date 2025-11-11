# Script to convert json outputs from the events_generator script to proper parquet files in S3
import json
import os
from datetime import datetime
from zoneinfo import ZoneInfo
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import boto3

# Get environement variables genrated by Terraform
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    LMain function triggered by SQS.
    Receives batch of messages, converts into Parquet and stores them in S3.
    """
    # SQS send the messages in 'Records'
    if 'Records' not in event:
        print("No records found in the event. Exit.")
        return

    records = event['Records']
    print(f"Received {len(records)} messages from SQS.")

 # 1. Extract and parse the JSON payload from each SQS message
    data_list = []
    for record in records:
        try:
            # The event payload is a JSON string in the 'body' key
            message_body = record['body']
            data = json.loads(message_body)
            data_list.append(data)
        except Exception as e:
            # Log the error but continue processing other valid messages in the batch
            print(f"JSON decoding error for one message, skipping: {e}")
            continue

    # Exit if the batch was empty or all messages failed parsing
    if not data_list:
        print("No valid data to process after parsing. Exiting.")
        return

    # 2. Convert the list of dictionaries into a Pandas DataFrame, then a PyArrow Table
    df = pd.DataFrame(data_list)
    arrow_table = pa.Table.from_pandas(df)

    # 3. Write the Arrow Table to an in-memory Parquet buffer
    parquet_buffer = pa.BufferOutputStream()
    pq.write_table(arrow_table, parquet_buffer)

    # 4. Define the S3 destination path and a unique filename
    # Use timezone-aware datetime.now(datetime.UTC) instead of deprecated utcnow()
    now = datetime.now(ZoneInfo("Europe/Paris"))
    
    # Generate a unique filename using the timestamp and Lambda request ID
    file_name = f"events_{now.strftime('%Y%m%d%H%M%S')}_{context.aws_request_id}.parquet"
    
    # Define the partitioned S3 key structure (e.g., .../YYYY/MM/DD/file.parquet)
    s3_key = f"realtime_data_platform_events/raw_data_events/{now.strftime('%Y/%m/%d')}/{file_name}"

    try:
        # Log the write operation
        print(f"Writing {len(data_list)} records to s3://{S3_BUCKET_NAME}/{s3_key}")
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=parquet_buffer.getvalue().to_pybytes()
        )
        print("✅ Successfully wrote Parquet file to S3.")
    except Exception as e:
        print(f"Error writing to S3: {e}")
        raise e

    return {
        'statusCode': 200,
        'body': json.dumps(f'Processed {len(data_list)} records successfully.')
    }   