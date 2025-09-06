import boto3
import json

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    
    try:
        # Amazon Linux 2023 최신 AMI 조회
        ami_response = ec2.describe_images(
            Owners=['amazon'],
            Filters=[
                {'Name': 'name', 'Values': ['al2023-ami-*-x86_64']},
                {'Name': 'state', 'Values': ['available']}
            ]
        )
        
        # 최신 AMI 선택
        latest_ami = sorted(ami_response['Images'], key=lambda x: x['CreationDate'], reverse=True)[0]
        ami_id = latest_ami['ImageId']
        
        # EC2 인스턴스 생성
        response = ec2.run_instances(
            ImageId=ami_id,
            MinCount=1,
            MaxCount=1,
            InstanceType='t3.micro',
            SubnetId='subnet-0f0a7f72b7f1d65af',
            TagSpecifications=[
                {
                    'ResourceType': 'instance',
                    'Tags': [
                        {
                            'Key': 'Name',
                            'Value': 'test_rocket'
                        }
                    ]
                }
            ]
        )
        
        instance_id = response['Instances'][0]['InstanceId']
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'EC2 instance created successfully',
                'instance_id': instance_id,
                'ami_id': ami_id
            })
        }
        
    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
