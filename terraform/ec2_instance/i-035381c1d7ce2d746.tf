resource "aws_instance" "i-035381c1d7ce2d746" {
  ami           = "ami-00ca32bbc84273381"
  instance_type = "t3.micro"
  subnet_id     = "subnet-0cd8237100f6181a4"
  vpc_security_group_ids = ["sg-0fc0b863835b5d766"]
}
