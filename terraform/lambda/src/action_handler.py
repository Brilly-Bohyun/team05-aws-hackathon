import json
import boto3
import subprocess
import os
from datetime import datetime
import urllib.parse

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
ec2 = boto3.client('ec2')
rds = boto3.client('rds')
lambda_client = boto3.client('lambda')
dynamodb_client = boto3.client('dynamodb')
codebuild = boto3.client('codebuild')

table = dynamodb.Table('${dynamodb_table}')

def lambda_handler(event, context):
    print(f"=== ACTION HANDLER START ===")
    print(f"Event: {json.dumps(event)}")
    
    try:
        # Slack에서 온 form-urlencoded 요청 파싱
        print(f"Parsing Slack request body...")
        print(f"Raw body: {event['body']}")
        
        # URL 디코딩
        parsed_body = urllib.parse.parse_qs(event['body'])
        print(f"Parsed body: {parsed_body}")
        
        if 'payload' not in parsed_body:
            raise ValueError("No payload found in request")
            
        payload_str = parsed_body['payload'][0]
        print(f"Payload string: {payload_str}")
        
        payload = json.loads(payload_str)
        print(f"Payload JSON: {json.dumps(payload, indent=2)}")
        
        if 'actions' not in payload or len(payload['actions']) == 0:
            raise ValueError("No actions found in payload")
            
        action_value = payload['actions'][0]['value']
        print(f"Action value: {action_value}")
        
        action_data = json.loads(action_value)
        action = action_data['action']
        event_id = action_data['event_id']
        
        print(f"Action: {action}, Event ID: {event_id}")
        
        # DynamoDB에서 이벤트 정보 조회
        print(f"Querying DynamoDB for event_id: {event_id}")
        response = table.get_item(Key={'event_id': event_id})
        
        if 'Item' not in response:
            print(f"Event not found in DynamoDB")
            return {'statusCode': 404, 'body': 'Event not found'}
        
        event_item = response['Item']
        print(f"Event item: {json.dumps(event_item, default=str)}")
        
        if action == 'delete':
            print(f"Deleting resource...")
            delete_resource(event_item)
        elif action == 'import':
            print(f"Importing to Terraform...")
            import_to_terraform(event_item)
        
        # 이벤트 상태 업데이트
        print(f"Updating event status...")
        table.update_item(
            Key={'event_id': event_id},
            UpdateExpression='SET #status = :status, processed_at = :timestamp',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'processed',
                ':timestamp': datetime.utcnow().isoformat()
            }
        )
        
        print(f"Action completed successfully")
        return {'statusCode': 200, 'body': 'Action completed'}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return {'statusCode': 500, 'body': str(e)}

def delete_resource(event_item):
    resource_type = event_item['resource_type']
    resource_id = event_item['resource_id']
    
    print(f"Deleting {resource_type}: {resource_id}")
    
    try:
        if resource_type == 's3_bucket':
            # S3 버킷 삭제 (객체 먼저 삭제 후 버킷 삭제)
            print(f"Deleting S3 bucket: {resource_id}")
            
            # 버킷 내 모든 객체 삭제
            try:
                objects = s3.list_objects_v2(Bucket=resource_id)
                if 'Contents' in objects:
                    print(f"Found {len(objects['Contents'])} objects to delete")
                    delete_keys = [{'Key': obj['Key']} for obj in objects['Contents']]
                    s3.delete_objects(
                        Bucket=resource_id,
                        Delete={'Objects': delete_keys}
                    )
                    print(f"Deleted all objects from bucket")
            except Exception as e:
                print(f"Error deleting objects (bucket might be empty): {str(e)}")
            
            # 버킷 삭제
            s3.delete_bucket(Bucket=resource_id)
            print(f"Deleted S3 bucket: {resource_id}")
            
        elif resource_type == 'ec2_instance':
            print(f"Terminating EC2 instance: {resource_id}")
            ec2.terminate_instances(InstanceIds=[resource_id])
            
        elif resource_type == 'rds_instance':
            print(f"Deleting RDS instance: {resource_id}")
            rds.delete_db_instance(
                DBInstanceIdentifier=resource_id,
                SkipFinalSnapshot=True
            )
            
        elif resource_type == 'lambda_function':
            print(f"Deleting Lambda function: {resource_id}")
            lambda_client.delete_function(FunctionName=resource_id)
            
        elif resource_type == 'dynamodb_table':
            print(f"Deleting DynamoDB table: {resource_id}")
            dynamodb_client.delete_table(TableName=resource_id)
            
        print(f"Successfully deleted {resource_type}: {resource_id}")
        
    except Exception as e:
        print(f"Error deleting resource: {str(e)}")
        raise

def import_to_terraform(event_item):
    resource_type = event_item['resource_type']
    resource_id = event_item['resource_id']
    resource_name = event_item['resource_name']
    
    print(f"Starting Terraform import for {resource_type}: {resource_name}")
    
    # Terraform 코드 생성
    terraform_code = generate_terraform_code(resource_type, resource_id, resource_name)
    
    # CodeBuild 프로젝트 시작
    try:
        response = codebuild.start_build(
            projectName='terraform-sync-import',
            environmentVariablesOverride=[
                {
                    'name': 'RESOURCE_TYPE',
                    'value': resource_type
                },
                {
                    'name': 'RESOURCE_ID',
                    'value': resource_id
                },
                {
                    'name': 'RESOURCE_NAME',
                    'value': resource_name
                },
                {
                    'name': 'TERRAFORM_CODE',
                    'value': terraform_code
                },
                {
                    'name': 'S3_BUCKET',
                    'value': '${s3_bucket}'
                },
                {
                    'name': 'STATE_BUCKET',
                    'value': '${s3_bucket}'
                },
                {
                    'name': 'GIT_REPO_URL',
                    'value': 'https://github.com/Brilly-Bohyun/team05-aws-hackathon.git'
                }
            ],

        )
        
        build_id = response['build']['id']
        print(f"CodeBuild started successfully. Build ID: {build_id}")
        print(f"Terraform import will be executed automatically")
        print(f"Check CodeBuild console for progress: {build_id}")
        
    except Exception as e:
        print(f"Error starting CodeBuild: {str(e)}")
        # Fallback: S3에만 저장
        s3_key = f"terraform/{resource_type}/{resource_name}.tf"
        s3.put_object(
            Bucket='${s3_bucket}',
            Key=s3_key,
            Body=terraform_code,
            ContentType='text/plain'
        )
        print(f"Fallback: Terraform code stored at s3://${s3_bucket}/{s3_key}")
        raise

def generate_terraform_code(resource_type, resource_id, resource_name):
    if resource_type == 's3_bucket':
        return f'''resource "aws_s3_bucket" "{resource_name}" {{
  bucket = "{resource_id}"
}}

resource "aws_s3_bucket_versioning" "{resource_name}" {{
  bucket = aws_s3_bucket.{resource_name}.id
  versioning_configuration {{
    status = "Enabled"
  }}
}}'''
    
    elif resource_type == 'ec2_instance':
        return f'''resource "aws_instance" "{resource_name}" {{
  # Import existing instance: {resource_id}
  # Run: terraform import aws_instance.{resource_name} {resource_id}
}}'''
    
    elif resource_type == 'rds_instance':
        return f'''resource "aws_db_instance" "{resource_name}" {{
  identifier = "{resource_id}"
  # Import existing RDS instance: {resource_id}
  # Run: terraform import aws_db_instance.{resource_name} {resource_id}
}}'''
    
    elif resource_type == 'lambda_function':
        return f'''resource "aws_lambda_function" "{resource_name}" {{
  function_name = "{resource_id}"
  # Import existing Lambda function: {resource_id}
  # Run: terraform import aws_lambda_function.{resource_name} {resource_id}
}}'''
    
    elif resource_type == 'dynamodb_table':
        return f'''resource "aws_dynamodb_table" "{resource_name}" {{
  name = "{resource_id}"
  # Import existing DynamoDB table: {resource_id}
  # Run: terraform import aws_dynamodb_table.{resource_name} {resource_id}
}}'''
    
    return f"# Unknown resource type: {resource_type}"