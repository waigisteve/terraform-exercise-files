provider "aws" {
  region = "us-west-2"  # Specify your AWS region
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

module "blog_sg" {
  source              = "terraform-aws-modules/security-group/aws"
  version             = "5.2.0"
  name                = "blog"
  vpc_id              = module.blog_vpc.vpc_id
  ingress_rules       = ["http-80-tcp"]  # Removed https-443-tcp
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules        = ["all-all"]
  egress_cidr_blocks  = ["0.0.0.0/0"]
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

module "alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name                = "blog-alb"
  load_balancer_type  = "application"

  vpc_id             = module.blog_vpc.vpc_id
  subnets            = module.blog_vpc.public_subnets
  security_groups    = [module.blog_sg.security_group_id]

  target_groups = {
    ex-instance = {
      name_prefix      = "blog"
      protocol         = "HTTP"
      port             = 80
      target_type      = "instance"
      target_id        = aws_instance.blog.id
    }
  }

  tags = {
    Environment = "Dev"
    Project     = "Example"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = module.alb.load_balancer_arn  # Correct reference to the ALB ARN
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = module.alb.target_groups.ex-instance.arn  # Ensure correct reference to the target group ARN
  }
}
