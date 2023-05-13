provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "web" {
  ami               = "ami-0889a44b331db0194"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  root_block_device {
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp2"
  }
  tags = {
    Name = "HelloWorld-Server"
  }
}

resource "aws_eip" "demoeip" {
  instance = aws_instance.web.id
  tags = {
    Name = "HelloWorld-EIP"
  }
}

# Creation of secondary volume
resource "aws_ebs_volume" "ec2-secondary-ebs" {
  availability_zone = "us-east-1a"
  size              = 9

  tags = {
    Name = "HelloWorld-Secondary-Volume"
  }
}

resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.ec2-secondary-ebs.id
  instance_id = aws_instance.web.id
}