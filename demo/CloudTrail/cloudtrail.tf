provider "aws" {
  region  = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "cloudtrail" {
    bucket = "${var.cloudtrail_bucket}"
    acl = "private"
    force_destroy = "true"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = "${aws_s3_bucket.cloudtrail.id}"
  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AWSCloudTrailAclCheck",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:GetBucketAcl",
            "Resource": "arn:aws:s3:::${var.cloudtrail_bucket}"
        },
        {
            "Sid": "AWSCloudTrailWrite",
            "Effect": "Allow",
            "Principal": {
              "Service": "cloudtrail.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::${var.cloudtrail_bucket}/*",
            "Condition": {
                "StringEquals": {
                    "s3:x-amz-acl": "bucket-owner-full-control"
                }
            }
        }
    ]
}
POLICY
}

resource "aws_cloudtrail" "cloudtrail" {
  name                          = "cloudtrail"
  s3_bucket_name                = "${aws_s3_bucket.cloudtrail.id}"
  s3_key_prefix                 = "cloudtrail"
  include_global_service_events = true
  is_multi_region_trail = true
  enable_log_file_validation = true
  enable_log_file_validation    = true
  cloud_watch_logs_role_arn     = "${aws_iam_role.cloudwatch.arn}"
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudwatch.arn}"

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::"]
    }
    
    data_resource {
      type   = "AWS::Lambda::Function"
      values = ["arn:aws:lambda"]
    }
  }
}

resource "aws_cloudwatch_log_group" "cloudwatch" {
  name     = "CloudTrail"
}

resource "aws_iam_role" "cloudwatch" {
  name               = "cloudtrail-cloudwatch"
  assume_role_policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
                "Service": "cloudtrail.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
POLICY
}
resource "aws_iam_policy" "cloudwatch" {
  name        = "cloudtrail-cloudwatch"
  description = "Allows CloudTrail to write logs to Cloudwatch"
  policy      = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailCreateLogStream",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:us-east-1:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.cloudwatch.name}:log-stream:*"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy_attachment" "cloudwatch" {
  name       = "cloudtrail-cloudwatch"
  roles      = ["${aws_iam_role.cloudwatch.name}"]
  policy_arn = "${aws_iam_policy.cloudwatch.arn}"
}



resource "aws_cloudwatch_log_metric_filter" "no-mfa" {
  name           = "SigninWithoutMFA"
  pattern        = "{ $.eventName = \"ConsoleLogin\" && $.additionalEventData.MFAUsed = \"No\" }"
  log_group_name = "${aws_cloudwatch_log_group.cloudwatch.name}"

  metric_transformation {
    name      = "SigninWithoutMFA"
    namespace = "Security"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "default" {
  alarm_name          = "SigninWithoutMFA"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "SigninWithoutMFA"
  namespace           = "Security"
  period              = "300"
  statistic           = "Sum"
  treat_missing_data  = "notBreaching"
  threshold           = "1"
  alarm_description   = "Alarms when a user logs into the console without MFA."
  alarm_actions       = ["arn:aws:sns:us-east-1:${data.aws_caller_identity.current.account_id}:notifications"]
}