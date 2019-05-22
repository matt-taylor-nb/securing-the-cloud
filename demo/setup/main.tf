provider "aws" {
  region  = "us-east-1"
}

resource "aws_sns_topic" "notifications" {
  name = "notifications"
}