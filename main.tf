terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region  = "us-west-2"
}

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

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dev"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_instance" "blog" {
  ami                    = data.aws_ami.app_ami.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [module.blog_sg.security_group_id]
  subnet_id              = module.blog_vpc.public_subnets[0]

  tags = {
    Name = "Learning Terraform"
  }
}

module "blog_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "5.2.0"
  name                = "blog"
  vpc_id              = module.blog_vpc.vpc_id
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"

  name            = "blog-alb"
  vpc_id          = module.blog_vpc.vpc_id
  subnets         = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  # Specify listeners with default actions
  listeners = [
    {
      port     = 80
      protocol = "HTTP"
      default_action = [
        {
          type = "redirect"  # Redirect HTTP to HTTPS
          redirect = {
            port        = "443"
            protocol    = "HTTPS"
            status_code = "HTTP_301"
          }
        }
      ]
    },
    {
      port     = 443
      protocol = "HTTPS"
      certificate_arn = "arn:aws:iam::123456789012:server-certificate/test_cert-123456789012"
      default_action = [
        {
          type = "forward"  # Forward to target group
          target_group_index = 0
        }
      ]
    }
  ]

  # Define target groups for the ALB
  target_groups = {
    ex-instance = {
      name_prefix      = "blog"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = aws_instance.blog.id  # Ensure this is accurate
      health_check = {
        path                = "/"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
      }
    }
  }

  tags = {
    Environment = "Dev"
    Project     = "Example"
  }
}
