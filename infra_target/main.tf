# ROLE Policy
data "aws_iam_policy_document" "chaos_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"

      identifiers = [
        "arn:aws:iam::${var.master_account}:root",
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "chaos_engineer" {
  name = "chaos-engineer"

  assume_role_policy = "${data.aws_iam_policy_document.chaos_role_policy.json}"
}

resource "aws_iam_role_policy" "role_policy_assume_role" {
  name = "chaos-policy-inline"
  role = "${aws_iam_role.chaos_engineer.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1357739573947",
      "Action": [
        "ec2:CreateTags",
        "ec2:DeleteSnapshot",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeVolumes",
        "ec2:TerminateInstances",
        "ses:SendEmail",
        "elasticloadbalancing:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "Stmt1357739649609",
      "Action": [
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "ssm:CancelCommand",
            "ssm:GetCommandInvocation",
            "ssm:ListCommandInvocations",
            "ssm:ListCommands",
            "ssm:SendCommand"
        ],
        "Resource": [
            "*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "ec2:DescribeInstanceAttribute",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeInstances"
        ],
        "Resource": [
            "*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "resource-groups:ListGroups",
            "resource-groups:ListGroupResources"
        ],
        "Resource": [
            "*"
        ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "tag:GetResources"
        ],
        "Resource": [
            "*"
        ]
    }
  ]
}
EOF
}

provider "aws" {
  region  = "${var.region}"
  profile = "${var.profile}"
}

terraform {
  backend "s3" {
    encrypt = "true"
    bucket  = "chaos-engineer-target"
    key     = "chaos/terraform.tfstate"
    region  = "us-east-1"
  }
}
