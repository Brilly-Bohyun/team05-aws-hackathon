resource "aws_instance" "$RESOURCE_NAME" {
  ami           = "$AMI_ID"
  instance_type = "$INSTANCE_TYPE"
  subnet_id     = "subnet-0cd8237100f6181a4"
  vpc_security_group_ids = ["sg-0fc0b863835b5d766"]
}
