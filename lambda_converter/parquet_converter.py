# Fichier: lambda_converter/parquet_converter.py
import json
import os
from datetime import datetime
import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
import boto3

# Récupérer les variables d'environnement définies par Terraform
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Fonction principale déclenchée par SQS.
    Elle reçoit un lot de messages, les convertit en Parquet et les dépose sur S3.
    """
    # SQS envoie les messages dans la clé 'Records'
    if 'Records' not in event:
        print("Aucun enregistrement trouvé dans l'événement. Sortie.")
        return

    records = event['Records']
    print(f"Reçu {len(records)} messages depuis SQS.")

    # 1. Extraire et parser les données JSON depuis les messages SQS
    data_list = []
    for record in records:
        try:
            # Le message est dans la clé 'body'
            message_body = record['body']
            data = json.loads(message_body)
            data_list.append(data)
        except Exception as e:
            print(f"Erreur de décodage JSON pour un message : {e}")
            continue

    if not data_list:
        print("Aucune donnée valide à traiter après le parsing. Sortie.")
        return

    # 2. Convertir les données en DataFrame Pandas, puis en table Arrow
    df = pd.DataFrame(data_list)
    arrow_table = pa.Table.from_pandas(df)

    # 3. Écrire la table Arrow en format Parquet dans un buffer en mémoire
    parquet_buffer = pa.BufferOutputStream()
    pq.write_table(arrow_table, parquet_buffer)

    # 4. Déposer le fichier Parquet sur S3
    now = datetime.utcnow()
    # Créer un nom de fichier unique pour éviter les écrasements
    file_name = f"events_{now.strftime('%Y%m%d%H%M%S')}_{context.aws_request_id}.parquet"
    s3_key = f"{now.strftime('%Y/%m/%d')}/{file_name}"

    try:
        print(f"Écriture de {len(data_list)} enregistrements dans le fichier {s3_key} sur le bucket {S3_BUCKET_NAME}...")
        s3_client.put_object(
            Bucket=S3_BUCKET_NAME,
            Key=s3_key,
            Body=parquet_buffer.getvalue().to_pybytes()
        )
        print("✅ Écriture sur S3 réussie.")
    except Exception as e:
        print(f"Erreur lors de l'écriture sur S3 : {e}")
        raise e

    return {
        'statusCode': 200,
        'body': json.dumps(f'Processed {len(data_list)} records successfully.')
    }