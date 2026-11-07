# Clúster ECS del modelo y recursos que comparten todos los entornos: security group de las
# tareas, rol de ejecución y log group. Los servicios, las task definitions y el rol de tarea
# los crea cada entorno.

resource "aws_ecs_cluster" "this" {
  name = "${var.modelo}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = "${var.modelo}-cluster"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

# Las tareas corren en las subredes públicas con IP pública y salen a internet (ECR, Secrets
# Manager, CloudWatch Logs) sin NAT. Solo reciben tráfico del ALB.
resource "aws_security_group" "tasks" {
  name        = "${var.modelo}-tareas"
  description = "Tareas ECS del modelo ${var.modelo}: backend solo desde el ALB, salida a internet"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-tareas"
  }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_backend" {
  security_group_id            = aws_security_group.tasks.id
  description                  = "Backend desde el ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.backend_port
  to_port                      = var.backend_port
  referenced_security_group_id = aws_security_group.alb.id

  tags = {
    Name = "${var.modelo}-tareas-backend"
  }
}

resource "aws_vpc_security_group_egress_rule" "tasks_all" {
  security_group_id = aws_security_group.tasks.id
  description       = "Todo el trafico de salida"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"

  tags = {
    Name = "${var.modelo}-tareas-salida"
  }
}

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    sid     = "AsumidoPorTareasEcs"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_execution" {
  name               = "${var.modelo}-ecs-execution"
  description        = "Rol de ejecucion de las tareas ECS del modelo ${var.modelo}"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = {
    Name = "${var.modelo}-ecs-execution"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# El agente de ECS lee los secretos del modelo (tesis/<modelo>/*) para inyectarlos en los contenedores.
data "aws_iam_policy_document" "ecs_execution_secrets" {
  statement {
    sid       = "LeerSecretosDelModelo"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${local.secrets_prefix}*"]
  }
}

resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name   = "${var.modelo}-ecs-execution-secretos"
  role   = aws_iam_role.ecs_execution.id
  policy = data.aws_iam_policy_document.ecs_execution_secrets.json
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.modelo}"
  retention_in_days = 7

  tags = {
    Name = "${var.modelo}-ecs-logs"
  }
}
