# ALB del modelo, compartido por todos los entornos: solo HTTPS 443, con el certificado wildcard
# regional. Los target groups y las reglas del listener los crea cada entorno.

resource "aws_security_group" "alb" {
  name        = "${var.modelo}-alb"
  description = "ALB del modelo ${var.modelo}: HTTPS desde internet, salida solo al backend en la VPC"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS desde internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.modelo}-alb-https"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_backend" {
  security_group_id = aws_security_group.alb.id
  description       = "Backend en las tareas de la VPC"
  ip_protocol       = "tcp"
  from_port         = var.backend_port
  to_port           = var.backend_port
  cidr_ipv4         = var.vpc_cidr

  tags = {
    Name = "${var.modelo}-alb-backend"
  }
}

resource "aws_lb" "this" {
  name                       = "${var.modelo}-alb"
  load_balancer_type         = "application"
  internal                   = false
  subnets                    = [for s in aws_subnet.public : s.id]
  security_groups            = [aws_security_group.alb.id]
  enable_deletion_protection = false

  tags = {
    Name = "${var.modelo}-alb"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.regional.certificate_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "no route"
      status_code  = "404"
    }
  }

  tags = {
    Name = "${var.modelo}-alb-https"
  }
}
