provider "aws" {
  region  = "us-east-1"
}

resource "aws_vpc" "demo" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "demo" {
  name        = "demo"
  description = "allow SSH to trigger rules"
  vpc_id      = "${aws_vpc.demo.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
  }
}
resource "aws_s3_bucket" "public" {
    bucket = "mattisawesome-public-test"
    acl = "public-read"
}