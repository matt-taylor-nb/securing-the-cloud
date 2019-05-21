provider "aws" {
  region  = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "config" {
    bucket = "${var.config_bucket}"
    acl = "private"
    force_destroy = "true"
}

resource "aws_s3_bucket_policy" "config" {
    bucket = "${aws_s3_bucket.config.id}"
    policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Allow bucket ACL check",
      "Effect": "Allow",
      "Principal": {
        "Service": [
         "config.amazonaws.com"
        ]
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${var.config_bucket}",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "true"
        }
      }
    },
    {
      "Sid": "Allow bucket write",
      "Effect": "Allow",
      "Principal": {
        "Service": [
         "config.amazonaws.com"
        ]
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.config_bucket}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        },
        "Bool": {
          "aws:SecureTransport": "true"
        }
      }
    },
    {
      "Sid": "Require SSL",
      "Effect": "Deny",
      "Principal": {
        "AWS": "*"
      },
      "Action": "s3:*",
      "Resource": "arn:aws:s3:::${var.config_bucket}/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY
}

resource "aws_config_configuration_recorder" "config" {
  name     = "awsconfig"
  role_arn = "${aws_iam_role.config.arn}"
  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = "${aws_config_configuration_recorder.config.name}"
  is_enabled = true

  depends_on = ["aws_config_delivery_channel.config"]
}

resource "aws_iam_role" "config" {
  name = "awsconfig-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = "${aws_iam_role.config.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_iam_role_policy" "config-sns"{
    role = "${aws_iam_role.config.name}"
    policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sns:Publish*",
      "Effect": "Allow",
      "Resource": "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:notifications"
    }
  ]
}
POLICY
}

resource "aws_config_delivery_channel" "config" {
  name           = "config"
  s3_bucket_name = "${aws_s3_bucket.config.bucket}"
  s3_key_prefix = "config"
  sns_topic_arn = "arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:notifications"
  depends_on     = ["aws_config_configuration_recorder.config"]
}

resource "aws_config_config_rule" "ct-enabled" {
  name = "CloudTrail-enabled"

  source {
    owner             = "AWS"
    source_identifier = "CLOUD_TRAIL_ENABLED"
  }

  depends_on = ["aws_config_configuration_recorder.config"]
}

resource "aws_config_config_rule" "s3-public" {
  name = "s3-public"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  depends_on = ["aws_config_configuration_recorder.config"]
}

resource "aws_config_config_rule" "incoming_ssh_disabled" {
  name = "incoming_ssh_disabled"

  source {
    owner             = "AWS"
    source_identifier = "INCOMING_SSH_DISABLED"
  }

  depends_on = ["aws_config_configuration_recorder.config"]
}