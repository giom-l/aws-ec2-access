provider "aws" {
  region  = "eu-west-3"
  version = ">= 3.8.0"
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
  vpc_id            = data.aws_vpc.current.id
  default_for_az    = true
  availability_zone = "eu-west-3a"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_vpc" "current" {
  id = var.vpc_id
}

# -----------------------------------------------------------------------------
# KMS Key to encrypt our data
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "key" {
  statement {
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root",
      ]
    }
    actions = [
      "kms:*",
    ]
    resources = [
      "*",
    ]
  }

  // Needed statement in KMS Key to allow the key to be used for encrypting cloudwatch logs
  statement {
    sid    = "AllowKMSKeyToBeUsedInCloudwatch"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    principals {
      identifiers = [
        "logs.${data.aws_region.current.name}.amazonaws.com"
      ]
      type = "Service"
    }
    resources = ["*"]
  }
}

resource "aws_kms_key" "key" {
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.key.json
  tags                    = local.tags
}

resource "aws_kms_alias" "key" {
  name          = "alias/${local.name}"
  target_key_id = aws_kms_key.key.key_id
}

# ------------------------------------------------------------------------------
# define the security group for the instance
# ------------------------------------------------------------------------------
resource "aws_security_group" "session_manager" {
  vpc_id      = data.aws_vpc.current.id
  name        = "session_manager"
  description = "security group that does not allow ssh in"

  ingress {
    description = "Allow HTTPS port from VPC for VPC Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = [data.aws_vpc.current.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = local.tags
}

# ------------------------------------------------------------------------------
# Define VPC Endpoints so we can use Session Manager without internet access
# See https://aws.amazon.com/premiumsupport/knowledge-center/ec2-systems-manager-vpc-endpoints/
# ------------------------------------------------------------------------------
data "aws_vpc_endpoint_service" "ssm" {
  service = "ssm"

}
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = data.aws_vpc.current.id
  service_name        = data.aws_vpc_endpoint_service.ssm.service_name
  subnet_ids          = [data.aws_subnet.selected.id]
  security_group_ids  = [aws_security_group.session_manager.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  tags                = local.tags
}

data "aws_vpc_endpoint_service" "ec2messages" {
  service = "ec2messages"
}
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = data.aws_vpc.current.id
  service_name        = data.aws_vpc_endpoint_service.ec2messages.service_name
  subnet_ids          = [data.aws_subnet.selected.id]
  security_group_ids  = [aws_security_group.session_manager.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  tags                = local.tags
}


data "aws_vpc_endpoint_service" "ssmmessages" {
  service = "ssmmessages"
}
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = data.aws_vpc.current.id
  service_name        = data.aws_vpc_endpoint_service.ssmmessages.service_name
  subnet_ids          = [data.aws_subnet.selected.id]
  security_group_ids  = [aws_security_group.session_manager.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  tags                = local.tags
}

data "aws_vpc_endpoint_service" "s3" {
  service = "s3"
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id              = data.aws_vpc.current.id
  service_name        = data.aws_vpc_endpoint_service.s3.service_name
  route_table_ids     = [data.aws_vpc.current.main_route_table_id]
  vpc_endpoint_type   = "Gateway"
  tags                = local.tags
}

data "aws_vpc_endpoint_service" "cloudwatch" {
  service = "logs"
}
resource "aws_vpc_endpoint" "cloudwatch" {
  vpc_id              = data.aws_vpc.current.id
  service_name        = data.aws_vpc_endpoint_service.cloudwatch.service_name
  subnet_ids          = [data.aws_subnet.selected.id]
  security_group_ids  = [aws_security_group.session_manager.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  tags                = local.tags
}

# ------------------------------------------------------------------------------
# Session-manager instance
# ------------------------------------------------------------------------------
resource "aws_instance" "session_manager" {
  ami                         = data.aws_ami.target_ami.id
  instance_type               = "t2.micro"
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.session_manager.id]
  associate_public_ip_address = false
  root_block_device {
    volume_type = "standard"
    volume_size = 8
  }
  key_name             = var.creation_key_name
  iam_instance_profile = aws_iam_instance_profile.session_manager.name
  tags                 = local.tags
  volume_tags          = local.tags
}

# -----------------------------------------------------------------------------
# S3 bucket where SSM logging will go
# Only needed if you want to store logs in S3
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "session_manager" {
  bucket = "session-manager-${data.aws_caller_identity.current.account_id}"
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.key.arn
      }
    }
  }
  force_destroy = true
}

# -----------------------------------------------------------------------------
# CloudWatch log group for our session
# Only needed if you want to store logs in Cloudwatch
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "session_manager" {
  name              = "/test/${local.name}"
  kms_key_id        = aws_kms_key.key.arn
  retention_in_days = "1"
}

# ------------------------------------------------------------------------------
# SSM Document which use will have to specify when initiating connection
# ------------------------------------------------------------------------------

resource "aws_ssm_document" "session_manager" {
  name            = "SSM-SessionManagerRunShell-${local.name}"
  document_type   = "Session"
  document_format = "JSON"
  tags            = local.tags

  content = jsonencode({
    schemaVersion = "1.0"
    description   = "Document to hold settings for Session Manager"
    sessionType   = "Standard_Stream"
    inputs = {
      // Add 3 following properties to send logs to s3
      s3BucketName        = aws_s3_bucket.session_manager.bucket
      s3KeyPrefix         = local.name
      s3EncryptionEnabled = true
      // Add 2 followings to send logs to cloudwatch
      cloudWatchLogGroupName      = aws_cloudwatch_log_group.session_manager.name
      cloudWatchEncryptionEnabled = true
      shellProfile = {
        linux = "bash"
      }
    }
  })
}
