data "aws_ami" "image" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2017.12.0.2018*"]
  }

  # owners = [""]
}

data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["*-non-prod"]
  }
}

data "aws_subnet_ids" "private_subnet" {
  vpc_id = "${data.aws_vpc.selected.id}"

  tags {
    Name = "*-private"
  }
}

data "aws_subnet" "subnet" {
  count = "${length(data.aws_subnet_ids.private_subnet.ids)}"
  id    = "${data.aws_subnet_ids.private_subnet.ids[count.index]}"
}

#
# IAM and Role
#

resource "aws_iam_instance_profile" "chaos_apps_profile" {
  name = "chaos_apps_role"
  role = "${aws_iam_role.chaos_apps_role.name}"
}

resource "aws_iam_role" "chaos_apps_role" {
  name = "chaos_apps_role"
  path = "/sre/"

  assume_role_policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Action": "sts:AssumeRole",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Effect": "Allow",
          "Sid": ""
        }
      ]
    }
EOF
}

resource "aws_iam_role_policy_attachment" "chaos_apps_attach" {
  role       = "${aws_iam_role.chaos_apps_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# aws autoscaling create-launch-configuration 
# --launch-configuration-name lc1 --instance-type t1.micro 
# --image-id ami-fcf27fcc --key-name <keyname>
resource "aws_launch_configuration" "lc" {
  name                 = "chaos-monkey-lc"
  image_id             = "${data.aws_ami.image.id}"
  instance_type        = "t2.micro"
  iam_instance_profile = "${aws_iam_instance_profile.chaos_apps_profile.name}"

  # key_name = "YOUR_KEY_HERE"

  root_block_device {
    delete_on_termination = true
  }
  user_data = <<EOF
  #!/bin/bash
  yum update -y
  yum install -y httpd
  service httpd start
  chkconfig httpd on
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

# aws autoscaling create-auto-scaling-group 
# --auto-scaling-group-name monkey-target --launch-configuration-name lc1 
# --availability-zones us-west-2a --min-size 1 --max-size 1
resource "aws_autoscaling_group" "this" {
  name                 = "monkey-target"
  launch_configuration = "${aws_launch_configuration.lc.name}"
  min_size             = 2
  max_size             = 2
  vpc_zone_identifier  = ["${data.aws_subnet.subnet.*.id}"]

  lifecycle {
    create_before_destroy = false
  }

  tag {
    key                 = "Name"
    value               = "Monkey-Instance"
    propagate_at_launch = true
  }
}

variable region {
  description = "Provide region to create these resources"
  default     = "us-east-1"
}

provider "aws" {
  region  = "${var.region}"
  profile = "saml"
}
