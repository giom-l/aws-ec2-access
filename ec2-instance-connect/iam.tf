# ------------------------------------------------------------------------------
# Configure IAM role for the instance to be able to be an EC2 instance :)
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "instance_connect" {
  name               = local.name
  description        = "Simple EC2"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_instance_profile" "instance_connect" {
  name = local.name
  role = aws_iam_role.instance_connect.id
}

# ------------------------------------------------------------------------------
# Create a user for our tests
# ------------------------------------------------------------------------------
resource "aws_iam_user" "instance_connect" {
  name = local.name
  tags = merge(map("Name", "instance_connect"), var.tags)
}

resource "aws_iam_access_key" "instance_connect" {
  user = aws_iam_user.instance_connect.name
}

# ------------------------------------------------------------------------------
# Configure policy to allow users to connect to instance
# ------------------------------------------------------------------------------
data "aws_iam_policy_document" "allow_instance_connect" {
  statement {
    sid    = "allowResourceAccessByName"
    effect = "Allow"
    actions = [
      "ec2-instance-connect:SendSSHPublicKey",
    ]
    condition {
      test     = "StringEquals"
      values   = ["ec2-user"]
      variable = "ec2:osuser"
    }
    resources = [
      "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.instance_connect.id}"
    ]
  }
  // This statement will give the same access as the previous one, it is just here to show how tags can be handled
  statement {
    sid    = "allowResourceAccessByTags"
    effect = "Allow"
    actions = [
      "ec2-instance-connect:SendSSHPublicKey",
    ]
    condition {
      test     = "StringEquals"
      values   = [local.name]
      variable = "aws:ResourceTag/Name"
    }
    resources = [
      "arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*"
    ]
  }

  statement {
    sid    = "AllowDescribeEC2Instances"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances"
    ]
    resources = [
      "*"
    ]
  }
}
resource "aws_iam_policy" "allow_instance_connect" {
  name        = local.name
  path        = "/${local.name}/"
  description = "Allows use of EC2 instance connect"
  policy      = data.aws_iam_policy_document.allow_instance_connect.json
}

resource "aws_iam_policy_attachment" "allow_instance_connect" {
  name       = local.name
  users      = [aws_iam_user.instance_connect.id]
  policy_arn = aws_iam_policy.allow_instance_connect.arn
}
