provider "aws" {
  region  = "us-east-1"
}

resource "aws_sns_topic" "notifications" {
  name = "notifications"
}

# resource "aws_sns_platform_application" "config" {
#   arn = "${aws_sns_topic.notifications.arn}"
# }