variable "ec2-ami" {
  type    = string
  default = "ami-06a0cd9728546d178"
}

variable "az-1" {
  type    = string
  default = "us-east-1a"
}

variable "all-ipv4" {
  type    = string
  default = "0.0.0.0/0"
}

variable "default-instance" {
  type    = string
  default = "t2.micro"
}