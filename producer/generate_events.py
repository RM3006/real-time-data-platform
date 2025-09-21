import json
import random
import time
from datetime import datetime, timezone
import boto3

EVENT_TYPES = ['page_view', 'add_to_cart', 'checkout', 'product_view']
PRODUCT_IDS = [f'prod-{i:04d}' for i in range(1, 101)]
USER_IDS = [f'user-{i:04d}' for i in range(1, 51)]

QUEUE_NAME = "realtime-platform-events-queue"
AWS_REGION = "eu-west-3" # Assurez-vous que c'est bien votre région

sqs_client = boto3.client('sqs', region_name=AWS_REGION)

try:
    queue_url = sqs_client.get_queue_url(QueueName=QUEUE_NAME)['QueueUrl']
except Exception as e:
    print(f"Erreur : Impossible de trouver la file SQS nommée '{QUEUE_NAME}' dans la région '{AWS_REGION}'. Vérifiez votre configuration Terraform. Erreur: {e}")
    exit()

def generate_event():
    """Génère un événement utilisateur simulé."""
    return {
        'event_id': f'evt_{int(time.time() * 1000)}_{random.randint(1000, 9999)}',
        'event_type': random.choice(EVENT_TYPES),
        'user_id': random.choice(USER_IDS),
        'product_id': random.choice(PRODUCT_IDS) if random.random() > 0.3 else None,
        # Ligne corrigée pour éviter le DeprecationWarning
        'event_timestamp': datetime.now(timezone.utc).isoformat(),
        'platform': random.choice(['web', 'mobile'])
    }

def main():
    """Fonction principale qui génère et envoie les événements à SQS."""
    print(f"Démarrage du producteur d'événements vers la file SQS '{QUEUE_NAME}'...")
    while True:
        event = generate_event()
        try:
            sqs_client.send_message(
                QueueUrl=queue_url,
                MessageBody=json.dumps(event)
            )
            print(f"Événement envoyé pour l'utilisateur: {event['user_id']}")
        except Exception as e:
            print(f"Erreur lors de l'envoi à SQS: {e}")
        time.sleep(random.uniform(0.1, 1.0))

if __name__ == "__main__":
    main()