###
# Lambda Role Policy
###

module "iam_assume_role_basic_execution" {
  source                        = "anonymint/iam-role/aws"
  role_name                     = "lambda-basic-execution-trigger-by-sns-role"
  policy_arns_count             = "1"
  policy_arns                   = ["arn:aws:iam::aws:policy/AWSOpsWorksCloudWatchLogs"]
  create_instance_role          = false
  iam_role_policy_document_json = "${data.aws_iam_policy_document.lambda_role_policy.json}"
}

resource "aws_iam_role" "lambda_role_accross_account" {
  name = "chaos-across-account"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "role_policy_assume_role" {
  count = "${length(split(",", var.target_accounts))}"
  name = "assume_role_target_${count.index}"
  role = "${aws_iam_role.lambda_role_accross_account.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "sts:AssumeRole",
            "Resource": "arn:aws:iam::${element(split(",", var.target_accounts), count.index)}:role/chaos-engineer"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "logs_related_policy" {
  name = "logs_related_policy"
  role = "${aws_iam_role.lambda_role_accross_account.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "sns:*"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ]
}
EOF
}

# ROLE Policy
data "aws_iam_policy_document" "lambda_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "lambda.amazonaws.com",
      ]
    }

    effect = "Allow"
  }
}

###
# Lambda function
###

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../chaos.py"
  output_path = "${path.module}/chaos_package.zip"
}

resource "aws_lambda_function" "chaos_lambda" {
  function_name = "chaos_monkey"
  handler       = "chaos.handler"

  //  role             = "${module.iam_assume_role.this_iam_role_arn}"
  role             = "${aws_iam_role.lambda_role_accross_account.arn}"
  runtime          = "python3.6"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  filename         = "${path.module}/chaos_package.zip"
  timeout          = 6

  environment {
    variables {
      target_accounts = "${var.target_accounts}"
      regions         = "${var.target_regions}"
      probability     = "${var.prob}"
      unleash_chaos   = "no"
      asg_group_name  = ""
      sns_alert_arn   = "${aws_sns_topic.alert.arn}"
    }
  }
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count         = "${length(var.schedule_run)}"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.chaos_lambda.function_name}"
  principal     = "events.amazonaws.com"
  statement_id  = "AlowExecutionFromCloudWatch-${count.index}"
  source_arn    = "${aws_cloudwatch_event_rule.scheduler.*.arn[count.index]}"
}

###
# CloudWatch
###
resource "aws_cloudwatch_event_rule" "scheduler" {
  count               = "${length(var.schedule_run)}"
  name                = "chaos_scheduler-${count.index}"
  description         = "This rule will trigger Lambda 9-3 5 days a week"
  schedule_expression = "${element(var.schedule_run, count.index)}"
}

resource "aws_cloudwatch_event_target" "target" {
  count = "${length(var.schedule_run)}"
  arn   = "${aws_lambda_function.chaos_lambda.arn}"
  rule  = "${aws_cloudwatch_event_rule.scheduler.*.name[count.index]}"
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.chaos_lambda.function_name}"
  retention_in_days = "7"
}

###
# Alert
###
# TODO send alert if killing happen
data "archive_file" "microsoft_connector_zip" {
  type        = "zip"
  source_file = "${path.module}/hook.py"
  output_path = "${path.module}/hook_package.zip"
}

resource "aws_lambda_function" "hook_lambda" {
  function_name    = "alert_hook"
  handler          = "hook.handler"
  role             = "${module.iam_assume_role_basic_execution.this_iam_role_arn}"
  runtime          = "python3.6"
  source_code_hash = "${data.archive_file.microsoft_connector_zip.output_base64sha256}"
  filename         = "${path.module}/hook_package.zip"

  environment {
    variables {
      hook_url = "${var.hook_url}"
    }
  }
}

resource "aws_lambda_permission" "allow_sns" {
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.hook_lambda.function_name}"
  principal     = "sns.amazonaws.com"
  statement_id  = "AlowExecutionFromSNS"
  source_arn    = "${aws_sns_topic.alert.arn}"
}

resource "aws_sns_topic" "alert" {
  name = "chaos-alert"
}

resource "aws_sns_topic_subscription" "lambda_sub" {
  endpoint  = "${aws_lambda_function.hook_lambda.arn}"
  protocol  = "lambda"
  topic_arn = "${aws_sns_topic.alert.arn}"
}

###
# DB
###
# TODO keep information in SDB or Dynamodb or whatnot as same as SimianMonkey

provider "aws" {
  region  = "${var.region}"
  profile = "saml"
}

terraform {
  backend "s3" {
    encrypt        = "true"
    bucket         = "chaos-engineer-master"
    key            = "chaos/terraform.tfstate"
    region         = "us-east-1"
    profile        = "saml"
  }
}
