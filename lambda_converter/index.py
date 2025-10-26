import json

def handler(event, context):
    print("Dummy placeholder function executed.")
    return {
        'statusCode': 200,
        'body': json.dumps('Hello from dummy Lambda!')
    }