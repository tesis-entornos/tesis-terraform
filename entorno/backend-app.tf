# Backend del entorno: base de datos lógica (la crea reset_baseline.py), bucket de archivos,
# rol de tarea, target group y regla en el ALB de la base, registro de origen y servicio ECS.

locals {
  db_master = jsondecode(data.aws_secretsmanager_secret_version.db_master.secret_string)

  files_bucket_name = "tesis-${local.name}-archivos-${var.account_id}"
  # ARN armado desde el nombre: así la política del rol se ve completa en el plan.
  files_bucket_arn = "arn:aws:s3:::${local.files_bucket_name}"
}

# --- DATABASE_URL ---------------------------------------------------------------

# La contraseña maestra es alfanumérica (base-modelo/secretos.tf): no hace falta codificarla.
resource "aws_secretsmanager_secret" "database_url" {
  name                    = "tesis/${var.modelo}/${var.slug}/database-url"
  description             = "DATABASE_URL del backend del entorno ${var.slug} (base ${local.database_name})"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name}-database-url"
  }
}

resource "aws_secretsmanager_secret_version" "database_url" {
  secret_id     = aws_secretsmanager_secret.database_url.id
  secret_string = "postgresql://${local.db_master.username}:${local.db_master.password}@${local.db_master.host}:${local.db_master.port}/${local.database_name}"
}

# --- Bucket de archivos ---------------------------------------------------------

resource "aws_s3_bucket" "files" {
  bucket        = local.files_bucket_name
  force_destroy = true

  tags = {
    Name = "${local.name}-archivos"
  }
}

resource "aws_s3_bucket_public_access_block" "files" {
  bucket = aws_s3_bucket.files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Rol de tarea ---------------------------------------------------------------

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

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  description        = "Rol de tarea del backend del entorno ${var.slug}: acceso a su bucket de archivos"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = {
    Name = "${local.name}-task"
  }
}

# ListBucket cubre también HeadBucket (readiness). Las versiones las usa reset_baseline.py.
data "aws_iam_policy_document" "task_files" {
  statement {
    sid       = "ListarBucketDeArchivos"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:ListBucketVersions"]
    resources = [local.files_bucket_arn]
  }

  statement {
    sid    = "ObjetosDelBucketDeArchivos"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
    ]
    resources = ["${local.files_bucket_arn}/*"]
  }
}

resource "aws_iam_role_policy" "task_files" {
  name   = "${local.name}-task-archivos"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_files.json
}

# --- ALB y DNS de origen --------------------------------------------------------

resource "aws_lb_target_group" "backend" {
  name                 = "${local.name}-tg"
  target_type          = "ip"
  protocol             = "HTTP"
  port                 = local.backend_port
  vpc_id               = local.base.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/api/v1/utils/health-check/"
    matcher             = "200"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name}-tg"
  }

  lifecycle {
    precondition {
      condition     = length("${local.name}-tg") <= 32
      error_message = "El nombre del target group (<modelo>-<slug>-tg) supera los 32 caracteres."
    }
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = local.base.https_listener_arn
  priority     = var.n * 10

  condition {
    host_header {
      values = [local.origin_fqdn]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }

  tags = {
    Name = "${local.name}-backend"
  }
}

resource "aws_route53_record" "origin" {
  zone_id = local.base.zone_id
  name    = local.origin_fqdn
  type    = "A"

  alias {
    name                   = local.base.alb_dns_name
    zone_id                = local.base.alb_zone_id
    evaluate_target_health = true
  }
}

# --- ECS ------------------------------------------------------------------------

resource "aws_ecs_task_definition" "backend" {
  family                   = "${local.name}-backend"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = local.base.execution_role_arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = "backend"
      image     = var.backend_image
      essential = true

      portMappings = [
        {
          containerPort = local.backend_port
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "PROJECT_NAME", value = var.project_name },
        { name = "FRONTEND_HOST", value = "https://${local.public_fqdn}" },
        { name = "FIRST_SUPERUSER", value = local.base.first_superuser_email },
        { name = "REDIS_URL", value = "redis://${local.base.cache_primary_endpoint}:6379/0" },
        { name = "CACHE_KEY_PREFIX", value = var.slug },
        { name = "S3_BUCKET", value = aws_s3_bucket.files.bucket },
        { name = "AWS_REGION", value = var.region },
      ]

      secrets = [
        { name = "DATABASE_URL", valueFrom = aws_secretsmanager_secret.database_url.arn },
        { name = "SECRET_KEY", valueFrom = local.base.secret_key_secret_arn },
        { name = "FIRST_SUPERUSER_PASSWORD", valueFrom = local.base.first_superuser_password_secret_arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.base.log_group_name
          awslogs-region        = var.region
          awslogs-stream-prefix = var.slug
        }
      }
    }
  ])

  tags = {
    Name = "${local.name}-backend"
  }
}

resource "aws_ecs_service" "backend" {
  name                              = "${local.name}-backend"
  cluster                           = local.base.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.backend.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = false

  network_configuration {
    subnets          = local.base.public_subnet_ids
    security_groups  = [local.base.tasks_security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.backend.arn
    container_name   = "backend"
    container_port   = local.backend_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = false
  }

  tags = {
    Name = "${local.name}-backend"
  }

  # El target group tiene que estar asociado al ALB (por la regla) antes de crear el servicio.
  depends_on = [aws_lb_listener_rule.backend]
}
