[너가 만들어줘야하는 서비스]
1. AWS 리소스를 생성할 때 Terraform으로 생성하거나 AWS 콘솔에서 생성함.
2. 대부분 Terraform으로 생성하지만 경우에 따라서 AWS 콘솔에서 생성하기도 함 (급한 조치, 업그레이드 작업 등)
3. Terraform을 사용할 때 이런 부분이 문제가 됨, 결국에는 실제 AWS 리소스 상태와 Terraform state를 일치시켜주는 서비스를 만들어줘야함


[이러한 흐름으로 갔으면 좋겠어]
1. 새로운 리소스가 생성되는 이벤트를 CloudTrail을 통해서 감지
2. Cloudtrail -> SNS -> SQS 순으로 이벤트가 전달
3. SQS에 저장된 이벤트를 서버에서 비동기적으로 하나씩 처리
4. 만약에 새로운 리소스가 생성된 이벤트라면 사용자에게 이걸 Terraform state로 관리할 것인지 삭제할 것인지 물어보는 슬랙 알림을 보낸다
5. 사용자가 받은 알림에서 삭제 버튼을 누르면 생성된 리소스가 그대로 삭제되고
6. 혹은 사용자가 유지 버튼을 누르면 해당 리소스를 import 하게됨, 이 때 테라폼 깃 레포지토리에도 커밋해야하고, 테라폼 state 에도 반영해야함
7. 6번 과정을 하기전에 항상 terraform plan, terraform run을 시행해야해.

[정보]
슬랙웹훅 : https://hooks.slack.com/services/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