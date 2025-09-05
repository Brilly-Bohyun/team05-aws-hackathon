import json
import boto3
import urllib3
from datetime import datetime
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('${dynamodb_table}')

def lambda_handler(event, context):
    for record in event['Records']:
        try:
            # SQS 메시지에서 CloudTrail 이벤트 파싱
            message = json.loads(record['body'])
            if 'Message' in message:
                cloudtrail_event = json.loads(message['Message'])
                
                # 리소스 생성 이벤트만 처리
                if is_resource_creation_event(cloudtrail_event):
                    process_creation_event(cloudtrail_event)
                    
        except Exception as e:
            print(f"Error processing record: {str(e)}")
    
    return {'statusCode': 200}

def is_resource_creation_event(event):
    creation_events = [
        'CreateBucket',
        'RunInstances', 
        'CreateDBInstance',
        'CreateFunction',
        'CreateTable'
    ]
    return event.get('eventName') in creation_events

def process_creation_event(event):
    event_id = str(uuid.uuid4())
    resource_info = extract_resource_info(event)
    
    # DynamoDB에 이벤트 저장
    table.put_item(
        Item={
            'event_id': event_id,
            'timestamp': datetime.utcnow().isoformat(),
            'event_name': event['eventName'],
            'resource_type': resource_info['type'],
            'resource_id': resource_info['id'],
            'resource_name': resource_info['name'],
            'aws_region': event['awsRegion'],
            'user_identity': event.get('userIdentity', {}),
            'status': 'pending'
        }
    )
    
    # Slack 알림 전송
    send_slack_notification(event_id, resource_info, event)

def extract_resource_info(event):
    event_name = event['eventName']
    
    if event_name == 'CreateBucket':
        return {
            'type': 's3_bucket',
            'id': event['requestParameters']['bucketName'],
            'name': event['requestParameters']['bucketName']
        }
    elif event_name == 'RunInstances':
        instances = event['responseElements']['instancesSet']['items']
        return {
            'type': 'ec2_instance',
            'id': instances[0]['instanceId'],
            'name': instances[0]['instanceId']
        }
    elif event_name == 'CreateDBInstance':
        return {
            'type': 'rds_instance',
            'id': event['requestParameters']['dBInstanceIdentifier'],
            'name': event['requestParameters']['dBInstanceIdentifier']
        }
    elif event_name == 'CreateFunction':
        return {
            'type': 'lambda_function',
            'id': event['requestParameters']['functionName'],
            'name': event['requestParameters']['functionName']
        }
    elif event_name == 'CreateTable':
        return {
            'type': 'dynamodb_table',
            'id': event['requestParameters']['tableName'],
            'name': event['requestParameters']['tableName']
        }
    
    return {'type': 'unknown', 'id': 'unknown', 'name': 'unknown'}

def send_slack_notification(event_id, resource_info, event):
    webhook_url = '${slack_webhook_url}'
    
    message = {
        "text": f"🚨 새로운 AWS 리소스가 생성되었습니다!",
        "blocks": [
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"*리소스 타입:* {resource_info['type']}\n*리소스 이름:* {resource_info['name']}\n*리전:* {event['awsRegion']}"
                }
            },
            {
                "type": "actions",
                "elements": [
                    {
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "text": "Terraform으로 관리"
                        },
                        "style": "primary",
                        "value": json.dumps({"action": "import", "event_id": event_id})
                    },
                    {
                        "type": "button",
                        "text": {
                            "type": "plain_text",
                            "text": "리소스 삭제"
                        },
                        "style": "danger",
                        "value": json.dumps({"action": "delete", "event_id": event_id})
                    }
                ]
            }
        ]
    }
    
    http = urllib3.PoolManager()
    response = http.request(
        'POST',
        webhook_url,
        body=json.dumps(message),
        headers={'Content-Type': 'application/json'}
    )