import json
import random
import time
import uuid
from datetime import datetime, timezone
import boto3

# --- Configuration ---

# 1. More Dimensions
UTM_SOURCES = ['google', 'facebook', 'twitter', 'linkedin', 'direct']
UTM_MEDIUMS = ['cpc', 'social', 'organic', 'referral', 'email']
UTM_CAMPAIGNS = ['summer_sale_2025', 'brand_awareness_q4', 'new_product_launch', None]

USER_AGENTS = [
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Linux; Android 13; SM-S908B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Mobile Safari/537.36'
]
IP_ADDRESSES = ['198.51.100.1', '203.0.113.25', '192.0.2.1', '233.252.0.100', '198.18.0.1']

# 2. More Facts & Dimensions
EVENT_TYPES = ['page_view', 'add_to_cart', 'remove_from_cart', 'checkout', 'product_view']

# Lists for real and "orphan" IDs
PRODUCT_IDS = [f'prod-{i:04d}' for i in range(1, 101)] # "Good" products
ORPHAN_PRODUCT_IDS = ['prod-9999', 'prod-8888']
USER_IDS = [f'user-{i:04d}' for i in range(1, 51)] # "Good" users
ORPHAN_USER_IDS = ['user-9999', 'user-7777']

# # --- Create a stable price catalog for all "good" products ---
# # This runs once, giving each "good" product a fixed price.
# PRODUCT_PRICES = {prod_id: round(random.uniform(5.0, 500.0), 2) for prod_id in PRODUCT_IDS}

# # --- NEW: Create a stable price catalog for "orphan" products ---
# # This also runs once, giving each "orphan" product its own fixed price.
# ORPHAN_PRODUCT_PRICES = {prod_id: round(random.uniform(10.0, 100.0), 2) for prod_id in ORPHAN_PRODUCT_IDS}

# # --- NEW: Combine both catalogs into one master price list ---
# ALL_PRODUCT_PRICES = {**PRODUCT_PRICES, **ORPHAN_PRODUCT_PRICES}


# 3. SQS Configuration (Unchanged)
QUEUE_NAME = "realtime-platform-events-queue"
AWS_REGION = "eu-west-3" 

# --- AWS SQS Client Initialization ---
sqs_client = boto3.client('sqs', region_name=AWS_REGION)
try:
    queue_url = sqs_client.get_queue_url(QueueName=QUEUE_NAME)['QueueUrl']
except Exception as e:
    print(f"Error: Could not find SQS queue named '{QUEUE_NAME}' in region '{AWS_REGION}'.")
    print(f"Please check your Terraform configuration or AWS console. Error: {e}")
    exit()

# Global variable to help create duplicate events
last_event_id_to_duplicate = None

def generate_event():
    """Generates a single, simulated, and potentially 'dirty' user event."""
    
    global last_event_id_to_duplicate
    
    # --- Generate Base Event ---
    event_type = random.choice(EVENT_TYPES)
    platform = random.choice(['web', 'mobile'])
    
    # --- 1. Create "Dirty" Timestamp ---
    if random.random() < 0.7:
        event_timestamp = datetime.now(timezone.utc).isoformat()
    else:
        event_timestamp = int(time.time())

    # --- 2. Create "Dirty" Event Type (Case Inconsistency) ---
    if random.random() < 0.1:
        event_type = event_type.upper()
    elif random.random() < 0.1:
        event_type = event_type.title()
    
    # --- 3. Create "Dirty" User ID (Nulls & Orphans) ---
    if random.random() < 0.1:
        user_id = None
    elif random.random() < 0.05:
        user_id = random.choice(ORPHAN_USER_IDS)
    else:
        user_id = random.choice(USER_IDS)

    # --- 4. Create "Dirty" Product ID (Nulls & Orphans) ---
    product_id = None
    # Only assign a product_id if it's a product-related event
    if event_type.lower() in ['add_to_cart', 'remove_from_cart', 'checkout', 'product_view']:
        if random.random() < 0.05:
            product_id = random.choice(ORPHAN_PRODUCT_IDS) # Use a *defined* orphan
        elif random.random() < 0.05:
             product_id = 'prod-7777' # Use an *undefined* orphan (will have no price)
        elif random.random() > 0.1: # 90% chance of a "good" product
            product_id = random.choice(PRODUCT_IDS)
        # (This leaves a small chance product_id is None on an e-commerce event, which is a bug!)
        
    # --- 5. Create "Dirty" Event ID (Duplicates) ---
    event_id = str(uuid.uuid4())
    if last_event_id_to_duplicate:
        event_id = last_event_id_to_duplicate
        last_event_id_to_duplicate = None
    elif random.random() < 0.05:
        last_event_id_to_duplicate = event_id

    # --- 6. Add New Dimensions (Marketing & Device) ---
    ip_address = random.choice(IP_ADDRESSES)
    user_agent = random.choice(USER_AGENTS)
    utm_source = random.choice(UTM_SOURCES)
    utm_medium = random.choice(UTM_MEDIUMS)
    utm_campaign = random.choice(UTM_CAMPAIGNS)
    
    # --- 7. Add New Facts (Value, Quantity, Order ID) ---
    order_id = None
    quantity = None
    # value = None
    
    event_type_lower = event_type.lower() if event_type else ''

    if event_type_lower == 'checkout':
        order_id = str(uuid.uuid4())
        quantity = random.randint(1, 10)
        
        if not product_id:
            product_id = random.choice(PRODUCT_IDS) # Assign a "good" product if checkout started with no product

        
    elif event_type_lower in ['add_to_cart', 'remove_from_cart']:
        quantity = 1
    
    # --- Assemble the Final Event Dictionary ---
    return {
        'event_id': event_id,
        'event_type': event_type, # Keep the original "dirty" casing
        'user_id': user_id,
        'product_id': product_id,
        'event_timestamp': event_timestamp,
        'platform': platform,
        'ip_address': ip_address,
        'user_agent': user_agent,
        'utm_source': utm_source,
        'utm_medium': utm_medium,
        'utm_campaign': utm_campaign,
        'order_id': order_id,
        'quantity': quantity
    }

def main():
    """Main function to generate and send events to SQS indefinitely."""
    
    print(f"Starting event producer. Sending events to SQS queue: '{QUEUE_NAME}'...")
    
    while True:
        event = generate_event()
        
        try:
            sqs_client.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(event)
            )
            print(f"Event sent for user: {event.get('user_id') or 'guest'}")
            
        except Exception as e:
            print(f"Error sending message to SQS: {e}")
            
        time.sleep(random.uniform(0.1, 1.0))

if __name__ == "__main__":
    main()


