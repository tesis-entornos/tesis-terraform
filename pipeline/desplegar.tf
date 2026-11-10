# Pipeline del modelo: un proyecto de CodeBuild por repo de CD. Cada push a la rama dev de
# tesis-backend-cd / tesis-frontend-cd (el entorno compartido del modelo) dispara el proyecto de ese
# servicio, que ejecuta desplegar-<modelo>.yml del bucket de buildspecs de la compartida.
# Mismo patrón que el build único de compartida/ (conexión importada, credencial de cuenta, rol,
# webhook y depends_on).

locals {
  desplegar_repos = {
    backend  = "tesis-backend-cd"
    frontend = "tesis-frontend-cd"
  }

  desplegar_name = "tesis-${var.modelo}-desplegar"

  # ARN del log group armado desde el nombre: así la política se ve completa en el plan.
  desplegar_log_group_arns = {
    for k, _ in local.desplegar_repos :
    k => "arn:aws:logs:${var.region}:${var.account_id}:log-group:/codebuild/${local.desplegar_name}-${k}"
  }

  desplegar_buildspec_arn = "arn:aws:s3:::${var.buildspecs_bucket}/${var.buildspecs_folder}/desplegar-${var.modelo}.yml"
}

# Creada y autorizada desde la consola (con la app instalada en la org tesis-entornos) e importada.
resource "aws_codeconnections_connection" "github" {
  name          = var.github_connection_name
  provider_type = "GitHub"
}

# Credencial de GitHub a nivel cuenta apuntando a la conexión. Sin ella, la validación de CodeBuild
# en CreateProject/UpdateProject con source CODECONNECTIONS falla con OAuthProviderException
# (ver compartida/publicador.tf).
resource "aws_codebuild_source_credential" "github" {
  server_type = "GITHUB"
  auth_type   = "CODECONNECTIONS"
  token       = aws_codeconnections_connection.github.arn

  # La API no devuelve el token: si la credencial se reimporta queda vacío en el state y, sin esto,
  # el plan la reemplazaría. Si cambia la conexión, hay que reemplazarla a mano (-replace).
  lifecycle {
    ignore_changes = [token]
  }
}

resource "aws_cloudwatch_log_group" "desplegar" {
  for_each = local.desplegar_repos

  name              = "/codebuild/${local.desplegar_name}-${each.key}"
  retention_in_days = 7
}

data "aws_iam_policy_document" "desplegar_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

# Un rol para los dos proyectos.
resource "aws_iam_role" "desplegar" {
  name               = local.desplegar_name
  assume_role_policy = data.aws_iam_policy_document.desplegar_assume.json
}

data "aws_iam_policy_document" "desplegar" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [for arn in values(local.desplegar_log_group_arns) : "${arn}:*"]
  }

  # El bucket de buildspecs es de la compartida y su política ya da lectura a esta cuenta.
  statement {
    sid       = "LeerBuildspecs"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.buildspecs_bucket}/${var.buildspecs_folder}/*"]
  }

  statement {
    sid       = "UsarConexionGitHub"
    effect    = "Allow"
    actions   = ["codeconnections:GetConnection", "codeconnections:GetConnectionToken"]
    resources = [aws_codeconnections_connection.github.arn]
  }
}

resource "aws_iam_role_policy" "desplegar" {
  name   = local.desplegar_name
  role   = aws_iam_role.desplegar.id
  policy = data.aws_iam_policy_document.desplegar.json
}

resource "aws_codebuild_project" "desplegar" {
  for_each = local.desplegar_repos

  name          = "${local.desplegar_name}-${each.key}"
  description   = "Despliegue de ${each.key} en el entorno compartido del ${var.modelo}: en cada push a dev de ${each.value}"
  service_role  = aws_iam_role.desplegar.arn
  build_timeout = 60
  # Sin concurrent_build_limit: con límite, los builds que lo superan fallan en vez de esperar.

  source {
    type            = "GITHUB"
    location        = "https://github.com/tesis-entornos/${each.value}.git"
    git_clone_depth = 1
    buildspec       = local.desplegar_buildspec_arn

    auth {
      type     = "CODECONNECTIONS"
      resource = aws_codeconnections_connection.github.arn
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type         = "ARM_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-aarch64-standard:4.0"

    environment_variable {
      name  = "SERVICIO"
      type  = "PLAINTEXT"
      value = each.key
    }

    environment_variable {
      name  = "GITHUB_CD_REPO"
      type  = "PLAINTEXT"
      value = each.value
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.desplegar[each.key].name
    }
  }

  # La política antes de que el proyecto use el rol, y la credencial de cuenta antes de que
  # CodeBuild valide la conexión.
  depends_on = [
    aws_iam_role_policy.desplegar,
    aws_codebuild_source_credential.github,
  ]
}

# Cualquier push a dev dispara, sin filtrar por archivo.
resource "aws_codebuild_webhook" "desplegar" {
  for_each = local.desplegar_repos

  project_name = aws_codebuild_project.desplegar[each.key].name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/dev$"
    }
  }
}
