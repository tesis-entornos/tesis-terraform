# Proyectos de cierre (proyectos_cierre, solo el efímero): uno por repo de CD. Al mergear o cerrar el
# PR de una rama de versión (release/c<N>-<n> o hotfix/c<N>-<n>) hacia main-efimero en
# tesis-backend-cd / tesis-frontend-cd, el proyecto de ese servicio ejecuta destruir-<modelo>.yml
# del bucket de buildspecs de la compartida, que decide si destruye el entorno de esa rama.
# Misma fuente principal, rol, imagen y variables que el proyecto de despliegue del mismo servicio
# (desplegar.tf). El rol no tiene sus log groups en la política inline: escriben por
# AdministratorAccess (proyectos_cierre requiere rol_administrador).

locals {
  cerrar_repos = var.proyectos_cierre ? local.desplegar_repos : {}

  cerrar_name = "tesis-${var.modelo}-cerrar"

  cerrar_buildspec_arn = "arn:aws:s3:::${var.buildspecs_bucket}/${var.buildspecs_folder}/destruir-${var.modelo}.yml"

  cerrar_webhook_base_ref_pattern = "^refs/heads/main-efimero$"
  cerrar_webhook_head_ref_pattern = "^refs/heads/(release|hotfix)/c[0-9]+-[0-9]+$"
}

resource "aws_cloudwatch_log_group" "cerrar" {
  for_each = local.cerrar_repos

  name              = "/codebuild/${local.cerrar_name}-${each.key}"
  retention_in_days = 7
}

resource "aws_codebuild_project" "cerrar" {
  for_each = local.cerrar_repos

  name          = "${local.cerrar_name}-${each.key}"
  description   = "Cierre de ${each.key} ${var.descripcion_destino}: al mergear o cerrar el PR de una rama de versión hacia main-efimero en ${each.value}"
  service_role  = aws_iam_role.desplegar.arn
  build_timeout = var.timeout_minutos

  source {
    type            = "GITHUB"
    location        = "https://github.com/tesis-entornos/${each.value}.git"
    git_clone_depth = var.git_clone_depth_principal
    buildspec       = local.cerrar_buildspec_arn

    auth {
      type     = "CODECONNECTIONS"
      resource = aws_codeconnections_connection.github.arn
    }
  }

  # Efímero: entorno/ de tesis-terraform fijado a un commit y el main del otro repo de CD con clon
  # completo (el buildspec lista sus ramas para decidir si destruye).
  dynamic "secondary_sources" {
    for_each = lookup(var.fuentes_secundarias_cierre, each.key, [])

    content {
      type              = "GITHUB"
      source_identifier = secondary_sources.value.source_identifier
      location          = "https://github.com/tesis-entornos/${secondary_sources.value.repo}.git"
      git_clone_depth   = secondary_sources.value.git_clone_depth

      auth {
        type     = "CODECONNECTIONS"
        resource = aws_codeconnections_connection.github.arn
      }
    }
  }

  dynamic "secondary_source_version" {
    for_each = lookup(var.fuentes_secundarias_cierre, each.key, [])

    content {
      source_identifier = secondary_source_version.value.source_identifier
      source_version    = secondary_source_version.value.version
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type            = "ARM_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux-aarch64-standard:4.0"
    privileged_mode = true

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

    dynamic "environment_variable" {
      for_each = local.con_secreto_superusuario

      content {
        name  = "FIRST_SUPERUSER_PASSWORD"
        type  = "SECRETS_MANAGER"
        value = local.first_superuser_password_secret_name
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.cerrar[each.key].name
    }
  }

  depends_on = [
    aws_iam_role_policy.desplegar,
    aws_iam_role_policy_attachment.desplegar_admin,
    aws_codebuild_source_credential.github,
  ]
}

# PR de una rama de versión hacia main-efimero, mergeado o cerrado sin mergear. Hasta que exista
# main-efimero en el repo de CD, no dispara.
resource "aws_codebuild_webhook" "cerrar" {
  for_each = local.cerrar_repos

  project_name = aws_codebuild_project.cerrar[each.key].name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PULL_REQUEST_MERGED,PULL_REQUEST_CLOSED"
    }

    filter {
      type    = "BASE_REF"
      pattern = local.cerrar_webhook_base_ref_pattern
    }

    filter {
      type    = "HEAD_REF"
      pattern = local.cerrar_webhook_head_ref_pattern
    }
  }

  # Sin esto, CodeBuild aplica ALL_PULL_REQUESTS a los webhooks nuevos: los eventos de PR de quien no
  # tenga un rol aprobador (por defecto admin, maintain o write) fallan hasta que alguien comente
  # /codebuild_run(<sha>). DISABLED: el cierre corre siempre, sin aprobación por comentario.
  pull_request_build_policy {
    requires_comment_approval = "DISABLED"
  }
}
