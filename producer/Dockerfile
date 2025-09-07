# Étape 1: Partir d'une image Python officielle et légère
FROM python:3.12-slim

# Étape 2: Définir le répertoire de travail à l'intérieur du conteneur
WORKDIR /app

# Étape 3: Copier le fichier des dépendances
COPY requirements.txt .

# Étape 4: Installer les dépendances
RUN pip install --no-cache-dir -r requirements.txt

# Étape 5: Copier notre script dans le conteneur
COPY generate_events.py .

# Étape 6: La commande à exécuter lorsque le conteneur démarre
CMD ["python", "generate_events.py"]