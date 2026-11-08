# Publicador de buildspecs: proyecto de CodeBuild que, en cada push a main o feature/* del repo
# tesis-buildspecs, ejecuta el buildspec.yml de su raíz y publica los archivos en el bucket de
# buildspecs.

locals {
  publicador_name = "tesis-publicar-buildspecs"
}

resource "aws_cloudwatch_log_group" "publicador" {
  name              = "/codebuild/${local.publicador_name}"
  retention_in_days = 7
}

data "aws_iam_policy_document" "publicador_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "publicador" {
  name               = local.publicador_name
  assume_role_policy = data.aws_iam_policy_document.publicador_assume.json
}

data "aws_iam_policy_document" "publicador" {
  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.publicador.arn}:*"]
  }

  statement {
    sid       = "ListarBucketBuildspecs"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.buildspecs.arn]
  }

  statement {
    sid       = "EscribirBucketBuildspecs"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.buildspecs.arn}/*"]
  }

  # Permisos documentados para que CodeBuild use una conexión de CodeConnections como source.
  statement {
    sid       = "UsarConexionGitHub"
    effect    = "Allow"
    actions   = ["codeconnections:GetConnection", "codeconnections:GetConnectionToken"]
    resources = [aws_codeconnections_connection.github.arn]
  }
}

resource "aws_iam_role_policy" "publicador" {
  name   = local.publicador_name
  role   = aws_iam_role.publicador.id
  policy = data.aws_iam_policy_document.publicador.json
}

# Credencial de GitHub a nivel cuenta (token/github), apuntando a la conexión tesis-entornos.
# Existe porque, con source CODECONNECTIONS, la validación que hace CodeBuild en
# CreateProject/UpdateProject falló con OAuthProviderException ("User is not authorized to access
# connection") hasta que la cuenta tuvo esta credencial; con ella, el mismo UpdateProject pasó.
# Se creó desde la consola (ImportSourceCredentials) y se importó.
resource "aws_codebuild_source_credential" "github" {
  server_type = "GITHUB"
  auth_type   = "CODECONNECTIONS"
  token       = aws_codeconnections_connection.github.arn

  # La API no devuelve el token: tras el import queda vacío en el state y, sin esto, el plan
  # reemplazaría la credencial. Si cambia la conexión, hay que reemplazarla a mano (-replace).
  lifecycle {
    ignore_changes = [token]
  }
}

resource "aws_codebuild_project" "publicador" {
  name          = local.publicador_name
  description   = "Publica los buildspecs del repo tesis-buildspecs en el bucket de buildspecs"
  service_role  = aws_iam_role.publicador.arn
  build_timeout = 10

  source {
    type            = "GITHUB"
    location        = "https://github.com/tesis-entornos/tesis-buildspecs.git"
    git_clone_depth = 1
    # Sin buildspec inline: usa el buildspec.yml de la raíz del repo.

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
      name  = "BUILDSPECS_BUCKET"
      value = aws_s3_bucket.buildspecs.bucket
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.publicador.name
    }
  }

  # La política tiene que estar puesta antes de que el proyecto use el rol, y la credencial de
  # cuenta antes de que CodeBuild valide la conexión.
  depends_on = [
    aws_iam_role_policy.publicador,
    aws_codebuild_source_credential.github,
  ]
}

resource "aws_codebuild_webhook" "publicador" {
  project_name = aws_codebuild_project.publicador.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/(main|feature/.+)$"
    }
  }
}
