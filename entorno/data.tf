# Outputs de la capa base-modelo/ del mismo modelo (VPC, ALB, ECS, RDS, ElastiCache, secretos).
data "terraform_remote_state" "base" {
  backend = "s3"

  config = {
    bucket  = "tesis-entornos-tfstate-${var.account_id}"
    key     = "base/terraform.tfstate"
    region  = var.region
    profile = var.aws_profile
  }
}

data "aws_route53_zone" "subzone" {
  zone_id = local.base.zone_id
}

# Credenciales del usuario maestro de RDS, para armar el DATABASE_URL del entorno.
data "aws_secretsmanager_secret_version" "db_master" {
  secret_id = local.base.db_master_secret_arn
}
