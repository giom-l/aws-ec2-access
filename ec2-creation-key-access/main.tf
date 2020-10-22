provider "aws" {
  region  = "eu-west-3"
  version = ">= 3.8.0"
}

provider "http" {
  version = ">= 1.2.0"
}
# -----------------------------------------------------------------------------
# data lookups
# -----------------------------------------------------------------------------
data "aws_availability_zones" "available" {}

data "aws_ami" "target_ami" {
  most_recent = true
  owners = [
  "amazon"]

  filter {
    name = "name"
    values = [
    "amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

data "aws_subnet" "selected" {
  vpc_id            = var.vpc_id
  default_for_az    = true
  availability_zone = "eu-west-3a"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# Current IP retrieving
# -----------------------------------------------------------------------------

data "http" "my_public_ip" {
  url = "https://ifconfig.co/json"
  request_headers = {
    Accept = "application/json"
  }
}

locals {
  ifconfig_co_json = jsondecode(data.http.my_public_ip.body)
}

# ------------------------------------------------------------------------------
# Upload a key pair to create instances
# ------------------------------------------------------------------------------
resource "aws_key_pair" "simple_ec2" {
  key_name   = "simple_ec2"
  public_key = file(var.key_path)
}

# ------------------------------------------------------------------------------
# define the security group for the instance
# ------------------------------------------------------------------------------
resource "aws_security_group" "simple_ec2" {
  vpc_id      = var.vpc_id
  name        = "simple-ec2-ssh "
  description = "security group that allows ssh in to target security group"

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
    "${local.ifconfig_co_json.ip}/32"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
  tags = local.tags
}

# ------------------------------------------------------------------------------
# Target instance
# ------------------------------------------------------------------------------
resource "aws_instance" "simple_ec2" {
  ami                         = data.aws_ami.target_ami.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.simple_ec2.id]
  associate_public_ip_address = true
  root_block_device {
    volume_type = "standard"
    volume_size = 8
  }
  key_name             = aws_key_pair.simple_ec2.key_name
  iam_instance_profile = aws_iam_instance_profile.simple_ec2.name
  tags                 = local.tags
  volume_tags          = local.tags
}