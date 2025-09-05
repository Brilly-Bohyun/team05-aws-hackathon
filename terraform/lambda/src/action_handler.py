import json
import boto3
import subprocess
import os
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
s3 = boto3.client('s3')
ec2 = boto3.client('ec2')
rds = boto3.client('rds')
lambda_client = boto3.client('lambda')
dynamodb_client = boto3.client('dynamodb')

table = dynamodb.Table('${dynamodb_table}')

def lambda_handler(event, context):
    try:
        # API Gateway에서 온 요청 파싱
        body = json.loads(event['body'])
        payload = json.loads(body['payload'])
        
        action_data = json.loads(payload['actions'][0]['value'])
        action = action_data['action']
        event_id = action_data['event_id']
        
        # DynamoDB에서 이벤트 정보 조회
        response = table.get_item(Key={'event_id': event_id})
        if 'Item' not in response:
            return {'statusCode': 404, 'body': 'Event not found'}
        
        event_item = response['Item']
        
        if action == 'delete':
            delete_resource(event_item)
        elif action == 'import':
            import_to_terraform(event_item)
        
        # 이벤트 상태 업데이트
        table.update_item(
            Key={'event_id': event_id},
            UpdateExpression='SET #status = :status, processed_at = :timestamp',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': 'processed',
                ':timestamp': datetime.utcnow().isoformat()
            }
        )
        
        return {'statusCode': 200, 'body': 'Action completed'}
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {'statusCode': 500, 'body': str(e)}

def delete_resource(event_item):
    resource_type = event_item['resource_type']
    resource_id = event_item['resource_id']
    
    try:
        if resource_type == 's3_bucket':
            # S3 버킷 삭제 (객체 먼저 삭제 후 버킷 삭제)
            s3.delete_bucket(Bucket=resource_id)
        elif resource_type == 'ec2_instance':
            ec2.terminate_instances(InstanceIds=[resource_id])
        elif resource_type == 'rds_instance':
            rds.delete_db_instance(
                DBInstanceIdentifier=resource_id,
                SkipFinalSnapshot=True
            )
        elif resource_type == 'lambda_function':
            lambda_client.delete_function(FunctionName=resource_id)
        elif resource_type == 'dynamodb_table':
            dynamodb_client.delete_table(TableName=resource_id)
            
        print(f"Successfully deleted {resource_type}: {resource_id}")
        
    except Exception as e:
        print(f"Error deleting resource: {str(e)}")
        raise

def import_to_terraform(event_item):
    resource_type = event_item['resource_type']
    resource_id = event_item['resource_id']
    resource_name = event_item['resource_name']
    
    # Terraform 코드 생성
    terraform_code = generate_terraform_code(resource_type, resource_id, resource_name)
    
    # S3에 Terraform 코드 저장
    s3_key = f"terraform/{resource_type}/{resource_name}.tf"
    s3.put_object(
        Bucket='${s3_bucket}',
        Key=s3_key,
        Body=terraform_code,
        ContentType='text/plain'
    )
    
    # Terraform import 실행 (실제 환경에서는 별도 시스템에서 실행)
    print(f"Terraform code generated for {resource_type}: {resource_name}")
    print(f"Stored at s3://${s3_bucket}/{s3_key}")
    
    # 실제로는 여기서 terraform import 명령을 실행해야 함
    # terraform_import_command = f"terraform import aws_{resource_type}.{resource_name} {resource_id}"
    # print(f"Run: {terraform_import_command}")

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