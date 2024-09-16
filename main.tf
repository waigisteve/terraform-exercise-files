provider "aws" {
  region = "us-west-2" # Ensure the correct region
}

# Fetch the most recent Bitnami Tomcat AMI
data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["bitnami-tomcat-*-x86_64-hvm-ebs-nami"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["979382823631"] # Bitnami
}

# Get default VPC (optional if needed)
data "aws_vpc" "default" {
  default = true
}

# VPC Module for the blog
module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]  # Change AZs to match your region
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]  # Ensure CIDRs match the VPC

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# Security Group Module for the blog instance
module "blog_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "5.2.0"
  name                = "blog"
  vpc_id              = module.blog_vpc.vpc_id  # Reference the correct VPC ID
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]  # Open to the world for HTTP/HTTPS traffic
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}

# AWS EC2 Instance for the blog
resource "aws_instance" "blog" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [module.blog_sg.security_group_id]
  subnet_id              = element(module.blog_vpc.public_subnets, 0)  # Reference the first public subnet

  tags = {
    Name = "Learning Terraform"
  }
}
