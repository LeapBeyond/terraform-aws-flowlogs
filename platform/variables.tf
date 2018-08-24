variable "tags" {
  default = {
    "owner"   = "rahook"
    "project" = "flowlogs-test"
    "client"  = "Internal"
  }
}

# -----------------------------------------------------------------------------
# network configuration
# -----------------------------------------------------------------------------

# 172.30.0.0 - 172.30.255.255
variable "vpc_cidr" {
  default = "172.30.0.0/16"
}

variable "ec2_subnet_cidr" {
  default = "172.30.10.0/26"
}

variable "nat_subnet_cidr" {
  default = "172.30.10.64/26"
}

# -----------------------------------------------------------------------------
# instance configuration
# -----------------------------------------------------------------------------

# internal ip of the NAT gateway
variable "eip_nat_ip" {
  default = "172.30.10.100"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "ami_name" {
  default = "amzn2-ami-hvm-2.0.20180810-x86_64-gp2"
}

variable "root_vol_size" {
  default = 8
}

variable "ec2_user" {
  default = "ec2-user"
}

# -----------------------------------------------------------------------------
# sundry bits
# -----------------------------------------------------------------------------
variable "stream_name" {
  default = "vpc-flowlogs-stream"
}

# -----------------------------------------------------------------------------
# variables to inject via terraform.tfvars or environment
# -----------------------------------------------------------------------------

variable "aws_account_id" {}
variable "aws_profile" {}
variable "aws_region" {}

variable "ec2_key" {}
variable "bastion_key" {}

variable "ssh_inbound" {
  type = "list"
}
