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
# Provision a new key in the instance authorized keys
# ------------------------------------------------------------------------------
data "local_file" "connection_key" {
  filename = var.key_path
}

data "template_file" "user_data" {
  template = <<EOF
#!/bin/bash -x

# First we create a group and a user
groupadd giom
useradd -m -g giom giom

# Ensure our public key is present in giom's authorized keys
install -o giom -g giom -m 700 -d /home/giom/.ssh

cat >> /home/giom/.ssh/authorized_keys << CFG
${data.local_file.connection_key.content}
CFG

# Set the right permissions to ssh files as root write them in user data
chmod 600 /home/giom/.ssh/authorized_keys
chown giom:giom /home/giom/.ssh/authorized_keys

EOF
}



# ------------------------------------------------------------------------------
# define the security group for the instance
# ------------------------------------------------------------------------------
resource "aws_security_group" "provision_key" {
  vpc_id      = var.vpc_id
  name        = "provision-key-ssh"
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
resource "aws_instance" "provision_key" {
  ami                         = data.aws_ami.target_ami.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.provision_key.id]
  associate_public_ip_address = true
  root_block_device {
    volume_type = "standard"
    volume_size = 8
  }
  key_name             = var.creation_key_name
  iam_instance_profile = aws_iam_instance_profile.provision_key.name
  tags                 = local.tags
  volume_tags          = local.tags
  user_data            = data.template_file.user_data.rendered
}