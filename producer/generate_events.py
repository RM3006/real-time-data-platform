import json
import random
import time
from datetime import datetime

EVENT_TYPES = ['page_view', 'add_to_cart', 'checkout', 'product_view']
PRODUCT_IDS = [f'prod-{i:04d}' for i in range(1, 101)]
USER_IDS = [f'user-{i:04d}' for i in range(1, 51)]

def generate_event():
    """Génère un événement utilisateur simulé."""
    event = {
        'event_id': f'evt_{int(time.time() * 1000)}_{random.randint(1000, 9999)}',
        'event_type': random.choice(EVENT_TYPES),
        'user_id': random.choice(USER_IDS),
        'product_id': random.choice(PRODUCT_IDS) if random.random() > 0.3 else None,
        'event_timestamp': datetime.utcnow().isoformat() + "Z",
        'platform': random.choice(['web', 'mobile'])
    }
    return event

def main():
    """Fonction principale qui génère et affiche les événements en continu."""
    print("Démarrage du générateur d'événements...")
    while True:
        event = generate_event()
        print(json.dumps(event, indent=4))
        # Simule une activité variable avec une petite pause
        time.sleep(random.uniform(0.1, 1.5))

if __name__ == "__main__":
    main()