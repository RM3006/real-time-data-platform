import json
import random
import time
from datetime import datetime, timezone
import boto3

# --- Configuration ---

# Define the possible event types that can be generated.
EVENT_TYPES = ['page_view', 'add_to_cart', 'checkout', 'product_view']

# Create a list of 100 simulated product IDs (e.g., "prod-0001", "prod-0100").
PRODUCT_IDS = [f'prod-{i:04d}' for i in range(1, 101)]

# Create a list of 50 simulated user IDs (e.g., "user-0001", "user-0050").
USER_IDS = [f'user-{i:04d}' for i in range(1, 51)]

# The name of the SQS queue, which must match the one created by Terraform.
QUEUE_NAME = "realtime-platform-events-queue"
# The AWS region where the queue exists.
AWS_REGION = "eu-west-3" # Make sure this matches your configuration

# --- AWS SQS Client Initialization ---

# Initialize the Boto3 client for SQS in the specified region.
sqs_client = boto3.client('sqs', region_name=AWS_REGION)

# Retrieve the actual URL for the queue from AWS using its name at startup.
try:
    queue_url = sqs_client.get_queue_url(QueueName=QUEUE_NAME)['QueueUrl']
except Exception as e:
    # If the queue is not found, print a fatal error and exit the script.
    print(f"Error: Could not find SQS queue named '{QUEUE_NAME}' in region '{AWS_REGION}'.")
    print(f"Please check your Terraform configuration or AWS console. Error: {e}")
    exit()

def generate_event():
    """Generates a single, simulated user event as a dictionary."""
    
    # Create a unique event ID using the current timestamp and a random number.
    event_id = f'evt_{int(time.time() * 1000)}_{random.randint(1000, 9999)}'
    
    # Select a random event type from the defined list.
    event_type = random.choice(EVENT_TYPES)
    
    # Select a random user for this event.
    user_id = random.choice(USER_IDS)
    
    # Assign a product ID for most events, but leave it null 30% of the time (e.g., for 'page_view').
    product_id = random.choice(PRODUCT_IDS) if random.random() > 0.3 else None
    
    # Get the current time in UTC, formatted as an ISO 8601 string.
    event_timestamp = datetime.now(timezone.utc).isoformat()
    
    # Assign a random platform.
    platform = random.choice(['web', 'mobile'])

    # Assemble the event dictionary.
    return {
        'event_id': event_id,
        'event_type': event_type,
        'user_id': user_id,
        'product_id': product_id,
        'event_timestamp': event_timestamp,
        'platform': platform
    }

def main():
    """Main function to generate and send events to SQS indefinitely."""
    
    print(f"Starting event producer. Sending events to SQS queue: '{QUEUE_NAME}'...")
    
    # Loop forever to continuously generate data.
    while True:
        # Generate a new, random event.
        event = generate_event()
        
        try:
            # Send the event to SQS. The MessageBody must be a JSON string.
            sqs_client.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(event)
            )
            print(f"Event sent for user: {event['user_id']}")
            
        except Exception as e:
            # Log any errors during sending but continue the loop to remain resilient.
            print(f"Error sending message to SQS: {e}")
            
        # Wait for a random, short duration (0.1s to 1.0s) to simulate a realistic event stream.
        time.sleep(random.uniform(0.1, 1.0))

# Standard Python entry point: run the 'main' function when the script is executed directly.
if __name__ == "__main__":
    main()