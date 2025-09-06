resource "aws_instance" "i-022292871fa922577" {
  ami           = "ami-06883c95d78ea3e7a"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0f0a7f72b7f1d65af"
  vpc_security_group_ids = ["sg-0a028877b6e96c0bc"]
}
resource "aws_instance" "i-0719fb0cd6f36b680" {
  ami           = "ami-00ca32bbc84273381"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0cd8237100f6181a4"
  vpc_security_group_ids = ["sg-031ae1f78feafe67a"]
}
