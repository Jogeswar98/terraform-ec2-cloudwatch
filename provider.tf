terraform {
  backend "s3" {
    bucket = "tws-portfolio01"  # <-- Replace with your bucket name
    key    = "ec2-instance/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
