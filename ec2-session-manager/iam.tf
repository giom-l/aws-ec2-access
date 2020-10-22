# ------------------------------------------------------------------------------
# Configure IAM role for the instance to be able to use instance connect
# We also allow SSM to send logs to cloudwatch and in S3 bucket
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      identifiers = [
      "ec2.amazonaws.com"]
      type = "Service"
    }
  }
}

//data "aws_iam_policy" "session_manager_default" {
//  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
//}

resource "aws_iam_role" "session_manager" {
  name               = local.name
  description        = "Role to allow instance to be connected through Session Manager"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "session_manager" {
  // Minimal permissions to use Session Manager.
  // The managed policy arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore allow GetParameter on * which we don't want
  statement {
    sid    = "AllowSSMMessagesUsage"
    effect = "Allow"
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  // Permissions to allow writing session logs in cloudwatch and encrypted s3
  statement {
    sid    = "AllowKMSKeyUsage"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
    ]
    resources = [
      aws_kms_key.key.arn
    ]
  }

  statement {
    sid    = "AllowCloudwatchListing"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = [
      "*"
    ]
  }

  statement {
    sid    = "AllowS3AuditLogging"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetEncryptionConfiguration"
    ]
    resources = [
      aws_s3_bucket.session_manager.arn,
      format("%s/*", aws_s3_bucket.session_manager.arn)
    ]
  }
}

resource "aws_iam_policy" "session_manager" {
  name        = "${local.name}-instance-policy"
  path        = "/${local.name}/"
  description = "Allows use of Session Manager"
  policy      = data.aws_iam_policy_document.session_manager.json
}

//resource "aws_iam_role_policy_attachment" "session_manager_ssmcore" {
//  role       = aws_iam_role.session_manager.id
//  policy_arn = data.aws_iam_policy.session_manager_default.arn
//}

resource "aws_iam_role_policy_attachment" "session_manager_s3cloudwatch" {
  role       = aws_iam_role.session_manager.id
  policy_arn = aws_iam_policy.session_manager.arn
}

resource "aws_iam_instance_profile" "session_manager" {
  name = local.name
  role = aws_iam_role.session_manager.id
}

# ------------------------------------------------------------------------------
# Create a user for our tests
# ------------------------------------------------------------------------------
resource "aws_iam_user" "session_manager" {
  name = local.name
  tags = merge(map("Name", "session-manager"), var.tags)
}

resource "aws_iam_access_key" "session_manager" {
  user = aws_iam_user.session_manager.name
}

# ------------------------------------------------------------------------------
# Configure policy to allow users to connect through session manager
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "allow_session_manager" {
  statement {
    sid    = "AllowDescribeEC2Instances"
    effect = "Allow"
    actions = [
      "ssm:DescribeSessions",
      "ssm:GetConnectionStatus",
      "ssm:DescribeInstanceProperties",
      "ec2:DescribeInstances"
    ]
    resources = [
      "*"
    ]
  }
  statement {
    sid    = "AllowStartSSMSession"
    effect = "Allow"
    actions = [
      "ssm:StartSession"
    ]
    resources = [
      "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*",
      aws_ssm_document.session_manager.arn
    ]
    // This condition enforces the user to specify a SSM document name when connecting. Otherwise, it could fallback to a default one.
    condition {
      test     = "BoolIfExists"
      values   = ["true"]
      variable = "ssm:SessionDocumentAccessCheck"
    }
    // We also grant access only to instances that have specific tag name
    condition {
      test     = "StringEquals"
      values   = [local.name]
      variable = "aws:ResourceTag/Name"
    }
  }
  statement {
    sid    = "AllowTerminateOwnSessionOnly"
    effect = "Allow"
    actions = [
      "ssm:TerminateSession"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:session/$${aws:username}-*"
    ]
  }
}

resource "aws_iam_policy" "allow_session_manager" {
  name        = "${local.name}-user-policy"
  path        = "/test/"
  description = "Allows use of Session Manager"
  policy      = data.aws_iam_policy_document.allow_session_manager.json
}

resource "aws_iam_policy_attachment" "allow_session_manager" {
  name       = local.name
  users      = [aws_iam_user.session_manager.id]
  policy_arn = aws_iam_policy.allow_session_manager.arn
}
