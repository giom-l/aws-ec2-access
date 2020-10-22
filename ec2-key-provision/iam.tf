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

resource "aws_iam_role" "provision_key" {
  name               = local.name
  description        = "Simple EC2"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_instance_profile" "provision_key" {
  name = local.name
  role = aws_iam_role.provision_key.id
}
