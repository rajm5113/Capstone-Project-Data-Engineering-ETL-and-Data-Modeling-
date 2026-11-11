data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "glue_base_policy" {
  statement {
    sid     = "AllowGlueToAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["glue.amazonaws.com"]
      type        = "Service"
    }
  }

  statement {
    sid     = "AllowEC2ToAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.project}-ec2-role"
      ]
      type = "AWS"
    }
  }
}

# This broad policy mirrors the training-lab configuration. For production,
# replace wildcard actions/resources with least-privilege permissions.
data "aws_iam_policy_document" "glue_access_policy" {
  statement {
    sid    = "AllowGlueAccess"
    effect = "Allow"

    actions = [
      "s3:*",
      "glue:*",
      "iam:*",
      "logs:*",
      "cloudwatch:*",
      "sqs:*",
      "ec2:*",
      "rds:*",
      "cloudtrail:*"
    ]

    resources = ["*"]
  }
}
