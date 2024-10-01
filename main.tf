module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"
  
  name = "dev"
  cidr = "10.0.0.0/16"
  
  azs = ["us-west-2a", "us-west-2b", "us-west-2c"]

  tags = {
    Environment = "dev"
  }
}

module "alb" {
  source = "terraform-aws-modules/alb/aws"
  
  providers = {
    aws = aws.secondary  # Use aliased provider if needed
  }

  name            = "blog-alb"
  vpc_id          = module.blog_vpc.vpc_id
  subnets         = module.blog_vpc.public_subnets
  security_groups = module.blog_sg.security_group_id
  
  listener {
    port     = 80
    protocol = "HTTP"
  
    default_action {
      type = "forward"
      target_group_arn = module.alb_target_group.target_group_arn
    }
  }
  
  tags = {
    Environment = "Dev"
    Project     = "Example"
  }
}

module "alb_target_group" {
  source = "terraform-aws-modules/alb/aws//modules/target-group"
  
  name_prefix = "blog"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.blog_vpc.vpc_id

  health_check {
    healthy_threshold   = 2
    interval            = 30
    timeout             = 5
    target              = "HTTP:80/"
    unhealthy_threshold = 2
  }

  tags = {
    Environment = "Dev"
    Project     = "Example"
  }
}
