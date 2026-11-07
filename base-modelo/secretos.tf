# Credenciales propias del modelo en Secrets Manager, bajo el prefijo tesis/<modelo>/.
# Reemplazan al secreto administrado por RDS, que rota cada 7 días y cortaría las conexiones
# en medio de una corrida. Estas no rotan: cambian solo si se recrea el random_password.
# Las contraseñas son alfanuméricas: no hace falta codificarlas en DATABASE_URL.

locals {
  secrets_prefix = "tesis/${var.modelo}/"
}

resource "random_password" "db_master" {
  length  = 32
  special = false
}

resource "random_password" "app_secret_key" {
  length  = 64
  special = false
}

resource "random_password" "first_superuser" {
  length  = 24
  special = false
}

# recovery_window_in_days = 0: se borran en el acto, así un destroy seguido de un apply
# puede volver a crear el mismo nombre.

resource "aws_secretsmanager_secret" "db_master" {
  name                    = "${local.secrets_prefix}db-master"
  description             = "Usuario maestro de RDS PostgreSQL del modelo ${var.modelo} (JSON: username, password, host, port)"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.modelo}-db-master"
  }
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    host     = aws_db_instance.postgres.address
    port     = aws_db_instance.postgres.port
  })
}

resource "aws_secretsmanager_secret" "secret_key" {
  name                    = "${local.secrets_prefix}secret-key"
  description             = "SECRET_KEY del backend del modelo ${var.modelo}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.modelo}-secret-key"
  }
}

resource "aws_secretsmanager_secret_version" "secret_key" {
  secret_id     = aws_secretsmanager_secret.secret_key.id
  secret_string = random_password.app_secret_key.result
}

resource "aws_secretsmanager_secret" "first_superuser_password" {
  name                    = "${local.secrets_prefix}first-superuser-password"
  description             = "FIRST_SUPERUSER_PASSWORD del backend del modelo ${var.modelo}"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.modelo}-first-superuser-password"
  }
}

resource "aws_secretsmanager_secret_version" "first_superuser_password" {
  secret_id     = aws_secretsmanager_secret.first_superuser_password.id
  secret_string = random_password.first_superuser.result
}
