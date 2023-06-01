variable "aws_region" {
  type    = string
  default = "sa-east-1"
}

variable "instance_type" {
  type    = string
  default = "t4g.small"
}

variable "ec2_az" {
  type    = string
  default = "sa-east-1a"
}

variable "ami" {
  type        = string
  default     = "ami-047b45c12c7b010f3"
  description = "Amazon Linux 2023 AMI 2023.0.20230517.1 arm64 HVM kernel-6.1"
}
