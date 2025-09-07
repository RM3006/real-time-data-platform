Ce dossier est utilisé pour exécuter un script python "generate_events.py" qui va créer des données factices.
Le script python s'exécute dans un container Docker.

Pour lancer le container lancer les commandes suivantes dans le terminal :
docker build -t realtime-producer:v1 ./producer
docker run --rm realtime-producer:v1