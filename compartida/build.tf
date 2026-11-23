# Build único: un proyecto de CodeBuild por repo de la aplicación. En cada PR de
# release/efimero/c<N>-<n> o release/fijo/c<N>-<n> hacia main construye la imagen con el buildspec
# publicado en el bucket de buildspecs y la sube a su repo de ECR. Docker Hub se usa autenticado
# (secreto tesis/compartida/dockerhub).

locals {
  build_repos = {
    backend  = "tesis-backend"
    frontend = "tesis-frontend"
  }

  # ARN del log group armado desde el nombre: así la política se ve completa en el plan.
  build_log_group_arns = {
    for k, _ in local.build_repos :
    k => "arn:aws:logs:${var.region}:${var.account_id}:log-group:/codebuild/tesis-build-${k}"
  }

  # Lo mismo para el repo de ECR: sin depender de aws_ecr_repository.this, la política no queda
  # "known after apply" cuando se suma otro repo al for_each.
  build_ecr_repository_arns = {
    for k, repo in local.build_repos :
    k => "arn:aws:ecr:${var.region}:${var.account_id}:repository/${repo}"
  }
}

resource "aws_cloudwatch_log_group" "build" {
  for_each = local.build_repos

  name              = "/codebuild/tesis-build-${each.key}"
  retention_in_days = 7
}

resource "aws_iam_role" "build" {
  for_each = local.build_repos

  name               = "tesis-build-${each.key}"
  assume_role_policy = data.aws_iam_policy_document.publicador_assume.json
}

data "aws_iam_policy_document" "build" {
  for_each = local.build_repos

  statement {
    sid       = "Logs"
    effect    = "Allow"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${local.build_log_group_arns[each.key]}:*"]
  }

  # GetAuthorizationToken no admite restricción por recurso.
  statement {
    sid       = "LoginEcr"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "PushPullRepoEcr"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
    ]
    resources = [local.build_ecr_repository_arns[each.key]]
  }

  statement {
    sid       = "LeerBuildspecs"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.buildspecs.arn}/*"]
  }

  statement {
    sid       = "LeerCredencialesDockerHub"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.dockerhub.arn]
  }

  statement {
    sid       = "LeerCredencialesGitHubCd"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_secretsmanager_secret.github_cd.arn]
  }

  # Los mismos permisos que el publicador para usar la conexión de GitHub como source.
  statement {
    sid       = "UsarConexionGitHub"
    effect    = "Allow"
    actions   = ["codeconnections:GetConnection", "codeconnections:GetConnectionToken"]
    resources = [aws_codeconnections_connection.github.arn]
  }
}

resource "aws_iam_role_policy" "build" {
  for_each = local.build_repos

  name   = "tesis-build-${each.key}"
  role   = aws_iam_role.build[each.key].id
  policy = data.aws_iam_policy_document.build[each.key].json
}

resource "aws_codebuild_project" "build" {
  for_each = local.build_repos

  name          = "tesis-build-${each.key}"
  description   = "Build único de ${each.value}: imagen a ECR en cada PR de release/* o hotfix/* hacia main"
  service_role  = aws_iam_role.build[each.key].arn
  build_timeout = 30

  source {
    type            = "GITHUB"
    location        = "https://github.com/tesis-entornos/${each.value}.git"
    git_clone_depth = 1
    buildspec       = "${aws_s3_bucket.buildspecs.arn}/${var.buildspecs_folder}/build-${each.key}.yml"

    auth {
      type     = "CODECONNECTIONS"
      resource = aws_codeconnections_connection.github.arn
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type            = "ARM_CONTAINER"
    compute_type    = "BUILD_GENERAL1_MEDIUM"
    image           = "aws/codebuild/amazonlinux-aarch64-standard:4.0"
    privileged_mode = true

    environment_variable {
      name  = "DOCKERHUB_USERNAME"
      type  = "SECRETS_MANAGER"
      value = "${aws_secretsmanager_secret.dockerhub.name}:username"
    }

    environment_variable {
      name  = "DOCKERHUB_TOKEN"
      type  = "SECRETS_MANAGER"
      value = "${aws_secretsmanager_secret.dockerhub.name}:token"
    }

    environment_variable {
      name  = "GITHUB_CD_USERNAME"
      type  = "SECRETS_MANAGER"
      value = "${aws_secretsmanager_secret.github_cd.name}:username"
    }

    environment_variable {
      name  = "GITHUB_CD_TOKEN"
      type  = "SECRETS_MANAGER"
      value = "${aws_secretsmanager_secret.github_cd.name}:token"
    }

    # Repo de CD de este proyecto: tesis-backend-cd / tesis-frontend-cd.
    environment_variable {
      name  = "GITHUB_CD_REPO"
      type  = "PLAINTEXT"
      value = "${each.value}-cd"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build[each.key].name
    }
  }

  # Igual que el publicador: la política antes de que el proyecto use el rol, y la credencial de
  # cuenta antes de que CodeBuild valide la conexión.
  depends_on = [
    aws_iam_role_policy.build,
    aws_codebuild_source_credential.github,
  ]
}

resource "aws_codebuild_webhook" "build" {
  for_each = local.build_repos

  project_name = aws_codebuild_project.build[each.key].name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_CREATED,PULL_REQUEST_UPDATED,PULL_REQUEST_REOPENED"
    }

    filter {
      type    = "BASE_REF"
      pattern = "^refs/heads/main$"
    }

    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/release/(efimero|fijo)/c[0-9]+-[0-9]+$"
    }

    filter {
      type    = "ACTOR_ACCOUNT_ID"
      pattern = "^(${join("|", var.github_pr_actor_ids)})$"
    }
  }

  # Sin esto, CodeBuild aplica ALL_PULL_REQUESTS a los webhooks nuevos: los PR de quien no tenga un
  # rol aprobador (por defecto admin, maintain o write) fallan hasta que alguien comente
  # /codebuild_run(<sha>). DISABLED: el build corre en cada PR, sin aprobación por comentario.
  pull_request_build_policy {
    requires_comment_approval = "DISABLED"
  }
}
