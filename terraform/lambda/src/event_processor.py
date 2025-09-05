import json
import boto3
import urllib3
from datetime import datetime
import uuid
import gzip
import io

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
table = dynamodb.Table('${dynamodb_table}')

def lambda_handler(event, context):
    print(f"=== LAMBDA START ===")
    print(f"Full Lambda event: {json.dumps(event, indent=2)}")
    print(f"Number of records: {len(event.get('Records', []))}")
    
    for i, record in enumerate(event['Records']):
        try:
            print(f"\n=== RECORD {i+1} ===")
            print(f"Record: {json.dumps(record, indent=2)}")
            
            # SQS 메시지 파싱
            message = json.loads(record['body'])
            print(f"\n=== SQS MESSAGE BODY ===")
            print(f"Message: {json.dumps(message, indent=2)}")
            
            # CloudTrail S3 파일 처리
            if 'Message' in message:
                cloudtrail_notification = json.loads(message['Message'])
                print(f"\n=== CLOUDTRAIL NOTIFICATION ===")
                print(f"Notification: {json.dumps(cloudtrail_notification, indent=2)}")
                
                if 's3Bucket' in cloudtrail_notification and 's3ObjectKey' in cloudtrail_notification:
                    bucket = cloudtrail_notification['s3Bucket']
                    object_keys = cloudtrail_notification['s3ObjectKey']
                    
                    print(f"Processing {len(object_keys)} CloudTrail files from S3")
                    
                    for object_key in object_keys:
                        print(f"\n=== PROCESSING S3 FILE ===")
                        print(f"Bucket: {bucket}, Key: {object_key}")
                        
                        # S3에서 CloudTrail 로그 파일 다운로드
                        cloudtrail_events = download_and_parse_cloudtrail_log(bucket, object_key)
                        
                        for event_data in cloudtrail_events:
                            event_name = event_data.get('eventName', 'Unknown')
                            print(f"Found event: {event_name}")
                            
                            if is_resource_creation_event(event_data):
                                print(f"Processing creation event: {event_name}")
                                process_creation_event(event_data)
                            else:
                                print(f"Skipping non-creation event: {event_name}")
                else:
                    print("No S3 bucket/key found in CloudTrail notification")
            else:
                print("No CloudTrail notification found")
                    
        except Exception as e:
            print(f"Error processing record {i+1}: {str(e)}")
            import traceback
            print(f"Traceback: {traceback.format_exc()}")
    
    print("\n=== LAMBDA END ===")
    return {'statusCode': 200}

def find_event_name(obj, path=""):
    """Recursively search for eventName in nested object"""
    if isinstance(obj, dict):
        if 'eventName' in obj:
            print(f"Found eventName at path '{path}': {obj['eventName']}")
            return obj['eventName']
        for key, value in obj.items():
            result = find_event_name(value, f"{path}.{key}" if path else key)
            if result != 'Unknown':
                return result
    elif isinstance(obj, list):
        for i, item in enumerate(obj):
            result = find_event_name(item, f"{path}[{i}]")
            if result != 'Unknown':
                return result
    elif isinstance(obj, str):
        try:
            # JSON 문자열인 경우 파싱 시도
            parsed = json.loads(obj)
            return find_event_name(parsed, f"{path}(parsed)")
        except:
            pass
    return 'Unknown'

def extract_event_data(message, event_name):
    """Extract full event data for the found eventName"""
    def search_for_event(obj):
        if isinstance(obj, dict):
            if obj.get('eventName') == event_name:
                return obj
            for value in obj.values():
                result = search_for_event(value)
                if result:
                    return result
        elif isinstance(obj, list):
            for item in obj:
                result = search_for_event(item)
                if result:
                    return result
        elif isinstance(obj, str):
            try:
                parsed = json.loads(obj)
                return search_for_event(parsed)
            except:
                pass
        return None
    
    return search_for_event(message)

def download_and_parse_cloudtrail_log(bucket, object_key):
    """S3에서 CloudTrail 로그 파일을 다운로드하고 파싱"""
    try:
        print(f"Downloading s3://{bucket}/{object_key}")
        
        # S3에서 파일 다운로드
        response = s3_client.get_object(Bucket=bucket, Key=object_key)
        
        # gzip 압축 해제
        with gzip.GzipFile(fileobj=io.BytesIO(response['Body'].read())) as gz_file:
            content = gz_file.read().decode('utf-8')
            
        print(f"Downloaded and decompressed {len(content)} characters")
        
        # JSON 파싱
        log_data = json.loads(content)
        records = log_data.get('Records', [])
        
        print(f"Found {len(records)} CloudTrail records")
        
        return records
        
    except Exception as e:
        print(f"Error downloading/parsing CloudTrail log: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return []

def is_resource_creation_event(event):
    creation_events = [
        'CreateBucket',
        'RunInstances', 
        'CreateDBInstance',
        'CreateFunction',
        'CreateTable'
    ]
    event_name = event.get('eventName', '')
    is_creation = event_name in creation_events
    
    print(f"Checking if '{event_name}' is a creation event: {is_creation}")
    print(f"Available creation events: {creation_events}")
    
    return is_creation

def process_creation_event(event):
    event_id = str(uuid.uuid4())
    print(f"Generated event_id: {event_id}")
    
    resource_info = extract_resource_info(event)
    print(f"Extracted resource info: {resource_info}")
    
    # DynamoDB에 이벤트 저장
    item = {
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
    
    print(f"Saving to DynamoDB: {json.dumps(item, default=str)}")
    
    try:
        table.put_item(Item=item)
        print("Successfully saved to DynamoDB")
    except Exception as e:
        print(f"Error saving to DynamoDB: {str(e)}")
        raise
    
    # Slack 알림 전송
    print("Sending Slack notification...")
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
    print(f"Sending Slack notification for event_id: {event_id}")
    print(f"Resource info: {resource_info}")
    print(f"Webhook URL: {webhook_url}")
    
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
    
    print(f"Slack message payload: {json.dumps(message)}")
    
    try:
        http = urllib3.PoolManager()
        response = http.request(
            'POST',
            webhook_url,
            body=json.dumps(message),
            headers={'Content-Type': 'application/json'}
        )
        
        print(f"Slack response status: {response.status}")
        print(f"Slack response data: {response.data.decode('utf-8')}")
        
        if response.status == 200:
            print("Slack notification sent successfully")
        else:
            print(f"Slack notification failed with status: {response.status}")
            
    except Exception as e:
        print(f"Error sending Slack notification: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        raise