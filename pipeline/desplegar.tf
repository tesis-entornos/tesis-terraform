# Pipeline del modelo: un proyecto de CodeBuild por repo de CD. Cada push a una rama que cumpla
# webhook_head_ref_pattern de tesis-backend-cd / tesis-frontend-cd dispara el proyecto de ese
# servicio, que ejecuta desplegar-<modelo>.yml del bucket de buildspecs de la compartida
# (fijo: dev, el entorno compartido; efímero: release/c<N>-<n> y hotfix/c<N>-<n>).
# Mismo patrón que el build único de compartida/ (conexión importada, credencial de cuenta, rol,
# webhook y depends_on). Los permisos del despliegue al entorno compartido y el secreto del
# superusuario se activan por modelo (permisos_despliegue_compartido, secreto_superusuario).

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

  # Recursos del backend del entorno compartido, con los nombres de base-modelo/ y entorno/
  # (<modelo>-<slug>): el despliegue registra una task definition nueva, corre las migraciones
  # como tarea one-off y actualiza el servicio.
  ecs_arn_prefix          = "arn:aws:ecs:${var.region}:${var.account_id}"
  compartido_name         = "${var.modelo}-compartido"
  ecs_cluster_name        = "${var.modelo}-cluster"
  ecs_cluster_arn         = "${local.ecs_arn_prefix}:cluster/${local.ecs_cluster_name}"
  compartido_backend_name = "${local.compartido_name}-backend"
  ecs_log_group_arn       = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/ecs/${var.modelo}"

  # Frontend del entorno compartido: bucket de entorno/ (tesis-<modelo>-<slug>-frontend-<cuenta>) y
  # su distribución de CloudFront. Imágenes de los repos de ECR de la compartida (backend, frontend
  # y la suite de Playwright).
  compartido_frontend_bucket_arn = "arn:aws:s3:::tesis-${local.compartido_name}-frontend-${var.account_id}"
  compartido_distribution_arn    = var.compartido_distribution_id == null ? null : "arn:aws:cloudfront::${var.account_id}:distribution/${var.compartido_distribution_id}"
  # Contraseña del superusuario (base-modelo/secretos.tf, texto plano, no JSON), para Playwright.
  # ARN con el patrón de sufijo de Secrets Manager: sigue valiendo si la base recrea el secreto.
  first_superuser_password_secret_name = "tesis/${var.modelo}/first-superuser-password"
  first_superuser_password_secret_arn  = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:${local.first_superuser_password_secret_name}-??????"

  # Bucket de registros del modelo (base-modelo/registros.tf): cada validación escribe el suyo.
  registros_bucket_arn = "arn:aws:s3:::tesis-${var.modelo}-registros-${var.account_id}"

  # for_each de los statements opcionales de la política: una vez o ninguna.
  con_despliegue_compartido = var.permisos_despliegue_compartido ? toset(["on"]) : toset([])
  con_secreto_superusuario  = var.secreto_superusuario ? toset(["on"]) : toset([])
  con_serializacion         = var.permisos_serializacion ? toset(["on"]) : toset([])

  # Bucket de states del modelo (estado/: tesis-entornos-tfstate-<cuenta>).
  tfstate_bucket_arn = "arn:aws:s3:::tesis-entornos-tfstate-${var.account_id}"

  # ARN de los proyectos armados desde el nombre (para la política, sin depender de los proyectos).
  desplegar_project_arns = [
    for k in sort(keys(local.desplegar_repos)) :
    "arn:aws:codebuild:${var.region}:${var.account_id}:project/${local.desplegar_name}-${k}"
  ]

  ecr_repository_arns = [
    for repo in ["tesis-backend", "tesis-frontend", "tesis-playwright"] :
    "arn:aws:ecr:${var.region}:${var.compartida_account_id}:repository/${repo}"
  ]
}

# Creada y autorizada desde la consola (con la app instalada en la org tesis-entornos) e importada.
# importar_conexion = true en el primer apply del modelo (la conexión ya existe y no está en el
# state); false después.
import {
  for_each = var.importar_conexion ? toset([var.github_connection_arn]) : toset([])
  to       = aws_codeconnections_connection.github
  id       = each.value
}

resource "aws_codeconnections_connection" "github" {
  name          = var.github_connection_name
  provider_type = "GitHub"

  # La política del rol usa var.github_connection_arn (conocido en el plan, también en el primer
  # apply, cuando la conexión se está importando): tiene que ser esta conexión.
  lifecycle {
    postcondition {
      condition     = self.arn == var.github_connection_arn
      error_message = "github_connection_arn no es el ARN de la conexión ${var.github_connection_name}."
    }
  }
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
  # Todos los prefijos (main/ y los de feature/), para probar buildspecs antes de mergear.
  statement {
    sid       = "LeerBuildspecs"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${var.buildspecs_bucket}/*"]
  }

  statement {
    sid       = "UsarConexionGitHub"
    effect    = "Allow"
    actions   = ["codeconnections:GetConnection", "codeconnections:GetConnectionToken"]
    resources = [var.github_connection_arn]
  }

  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "ActualizarServicioBackend"
      effect    = "Allow"
      actions   = ["ecs:DescribeServices", "ecs:UpdateService"]
      resources = ["${local.ecs_arn_prefix}:service/${local.ecs_cluster_name}/${local.compartido_backend_name}"]
    }
  }

  # DescribeTaskDefinition y RegisterTaskDefinition no admiten restricción por recurso.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "RegistrarTaskDefinition"
      effect    = "Allow"
      actions   = ["ecs:DescribeTaskDefinition", "ecs:RegisterTaskDefinition"]
      resources = ["*"]
    }
  }

  # La task definition se registra con sus tags (default_tags de entorno/): solo al registrarla.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "EtiquetarTaskDefinition"
      effect    = "Allow"
      actions   = ["ecs:TagResource"]
      resources = ["${local.ecs_arn_prefix}:task-definition/${local.compartido_backend_name}:*"]

      condition {
        test     = "StringEquals"
        variable = "ecs:CreateAction"
        values   = ["RegisterTaskDefinition"]
      }
    }
  }

  # Tarea one-off de migraciones con la task definition del backend, solo en el cluster del modelo.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "CorrerMigraciones"
      effect    = "Allow"
      actions   = ["ecs:RunTask"]
      resources = ["${local.ecs_arn_prefix}:task-definition/${local.compartido_backend_name}:*"]

      condition {
        test     = "ArnEquals"
        variable = "ecs:cluster"
        values   = [local.ecs_cluster_arn]
      }
    }
  }

  # El run-task de migraciones usa --propagate-tags TASK_DEFINITION: solo al lanzar la tarea.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "EtiquetarTareas"
      effect    = "Allow"
      actions   = ["ecs:TagResource"]
      resources = ["${local.ecs_arn_prefix}:task/${local.ecs_cluster_name}/*"]

      condition {
        test     = "StringEquals"
        variable = "ecs:CreateAction"
        values   = ["RunTask"]
      }
    }
  }

  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "SeguirTareas"
      effect    = "Allow"
      actions   = ["ecs:DescribeTasks", "ecs:StopTask"]
      resources = ["${local.ecs_arn_prefix}:task/${local.ecs_cluster_name}/*"]
    }
  }

  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid     = "PasarRolesBackend"
      effect  = "Allow"
      actions = ["iam:PassRole"]
      resources = [
        "arn:aws:iam::${var.account_id}:role/${var.modelo}-ecs-execution",
        "arn:aws:iam::${var.account_id}:role/${local.compartido_name}-task",
      ]

      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["ecs-tasks.amazonaws.com"]
      }
    }
  }

  # Para imprimir la salida de la migración: FilterLogEvents es sobre el log group y GetLogEvents
  # sobre los streams.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "LeerLogsEcs"
      effect    = "Allow"
      actions   = ["logs:GetLogEvents", "logs:FilterLogEvents"]
      resources = [local.ecs_log_group_arn, "${local.ecs_log_group_arn}:log-stream:*"]
    }
  }

  dynamic "statement" {
    for_each = local.con_secreto_superusuario

    content {
      sid       = "LeerPasswordSuperusuario"
      effect    = "Allow"
      actions   = ["secretsmanager:GetSecretValue"]
      resources = [local.first_superuser_password_secret_arn]
    }
  }

  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "EscribirRegistrosValidaciones"
      effect    = "Allow"
      actions   = ["s3:PutObject"]
      resources = ["${local.registros_bucket_arn}/validaciones/*"]
    }
  }

  # GetAuthorizationToken no admite restricción por recurso.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "LoginEcr"
      effect    = "Allow"
      actions   = ["ecr:GetAuthorizationToken"]
      resources = ["*"]
    }
  }

  # Pull de las imágenes de la compartida (la política de los repos ya da lectura a esta cuenta).
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid    = "PullImagenesCompartida"
      effect = "Allow"
      actions = [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability",
      ]
      resources = local.ecr_repository_arns
    }
  }

  # Publicación del frontend del compartido: sync/cp/rm de aws s3.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "ListarBucketFrontend"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [local.compartido_frontend_bucket_arn]
    }
  }

  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "PublicarFrontend"
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:DeleteObject"]
      resources = ["${local.compartido_frontend_bucket_arn}/*"]
    }
  }

  # Registro del último despliegue del frontend en el bucket.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "LeerRegistroFrontend"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${local.compartido_frontend_bucket_arn}/_despliegue.json"]
    }
  }

  # Invalidación de /* después de copiar, esperando Completed.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "InvalidarCloudFront"
      effect    = "Allow"
      actions   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
      resources = [local.compartido_distribution_arn]
    }
  }

  # El script busca la distribución por alias; ListDistributions no admite restricción por recurso.
  dynamic "statement" {
    for_each = local.con_despliegue_compartido

    content {
      sid       = "ListarDistribuciones"
      effect    = "Allow"
      actions   = ["cloudfront:ListDistributions"]
      resources = ["*"]
    }
  }

  # Serialización por entorno: cada build lista los builds en curso de los proyectos del modelo y
  # espera a los de su misma rama que arrancaron antes.
  dynamic "statement" {
    for_each = local.con_serializacion

    content {
      sid       = "SerializarBuilds"
      effect    = "Allow"
      actions   = ["codebuild:ListBuildsForProject", "codebuild:BatchGetBuilds"]
      resources = local.desplegar_project_arns
    }
  }

  # Marcas de turno de la serialización: entornos/<slug>/turnos/<build-id>.json en el bucket de
  # states del modelo. Cada build escribe la suya y lee las de su slug.
  dynamic "statement" {
    for_each = local.con_serializacion

    content {
      sid       = "EscribirTurnos"
      effect    = "Allow"
      actions   = ["s3:PutObject", "s3:GetObject"]
      resources = ["${local.tfstate_bucket_arn}/entornos/*/turnos/*"]
    }
  }

  dynamic "statement" {
    for_each = local.con_serializacion

    content {
      sid       = "ListarTurnos"
      effect    = "Allow"
      actions   = ["s3:ListBucket"]
      resources = [local.tfstate_bucket_arn]

      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values   = ["entornos/*"]
      }
    }
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
  description   = "Despliegue de ${each.key} ${var.descripcion_destino}: ${var.descripcion_disparo} de ${each.value}"
  service_role  = aws_iam_role.desplegar.arn
  build_timeout = var.timeout_minutos
  # Sin concurrent_build_limit: con límite, los builds que lo superan fallan en vez de esperar.

  source {
    type            = "GITHUB"
    location        = "https://github.com/tesis-entornos/${each.value}.git"
    git_clone_depth = var.git_clone_depth_principal
    buildspec       = local.desplegar_buildspec_arn

    auth {
      type     = "CODECONNECTIONS"
      resource = aws_codeconnections_connection.github.arn
    }
  }

  # Fuentes secundarias del proyecto (efímero: el código de entorno/ fijado a un commit y el repo de
  # CD del otro servicio en main), con la misma conexión. Cada una queda en
  # $CODEBUILD_SRC_DIR_<source_identifier>. El repo propio no puede ser secundaria (CodeBuild
  # rechaza dos fuentes con la misma location): su main se lee del clon completo de la principal
  # (git_clone_depth_principal = 0, git show origin/main:tag.json).
  dynamic "secondary_sources" {
    for_each = lookup(var.fuentes_secundarias, each.key, [])

    content {
      type              = "GITHUB"
      source_identifier = secondary_sources.value.source_identifier
      location          = "https://github.com/tesis-entornos/${secondary_sources.value.repo}.git"
      git_clone_depth   = 1

      auth {
        type     = "CODECONNECTIONS"
        resource = aws_codeconnections_connection.github.arn
      }
    }
  }

  dynamic "secondary_source_version" {
    for_each = lookup(var.fuentes_secundarias, each.key, [])

    content {
      source_identifier = secondary_source_version.value.source_identifier
      source_version    = secondary_source_version.value.version
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    type         = "ARM_CONTAINER"
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux-aarch64-standard:4.0"
    # Docker: pull y cp de la imagen del frontend, y Playwright en los dos proyectos.
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

    # Para la suite Playwright después del despliegue.
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

# Cualquier push a una rama que cumpla webhook_head_ref_pattern dispara, sin filtrar por archivo.
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
      pattern = var.webhook_head_ref_pattern
    }
  }
}
