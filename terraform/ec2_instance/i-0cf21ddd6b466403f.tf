resource "aws_instance" "i-0cf21ddd6b466403f" {
  ami           = "ami-06883c95d78ea3e7a"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0f0a7f72b7f1d65af"
  vpc_security_group_ids = ["sg-0a028877b6e96c0bc"]
}
