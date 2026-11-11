output "zone_id" {
  description = "ID de la subzona del modelo"
  value       = aws_route53_zone.subzone.zone_id
}

output "name_servers" {
  description = "Name servers de la subzona del modelo"
  value       = aws_route53_zone.subzone.name_servers
}

output "certificate_arn_us_east_1" {
  description = "ARN del certificado wildcard validado en us-east-1 (CloudFront)"
  value       = aws_acm_certificate_validation.us_east_1.certificate_arn
}

output "certificate_arn_regional" {
  description = "ARN del certificado wildcard validado en la región del modelo (ALB)"
  value       = aws_acm_certificate_validation.regional.certificate_arn
}

output "vpc_id" {
  description = "ID de la VPC del modelo"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs de las subredes públicas, en el orden de azs"
  value       = [for k in keys(local.subnets) : aws_subnet.public[k].id]
}

output "private_subnet_ids" {
  description = "IDs de las subredes privadas, en el orden de azs"
  value       = [for k in keys(local.subnets) : aws_subnet.private[k].id]
}

output "alb_arn" {
  description = "ARN del ALB del modelo"
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Nombre DNS del ALB, destino de los alias de cada entorno"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID del ALB, para los registros alias de Route 53"
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "ARN del listener HTTPS 443, donde cada entorno agrega sus reglas"
  value       = aws_lb_listener.https.arn
}

output "alb_security_group_id" {
  description = "ID del security group del ALB, origen permitido en el security group de las tareas"
  value       = aws_security_group.alb.id
}

output "db_address" {
  description = "Hostname de RDS PostgreSQL"
  value       = aws_db_instance.postgres.address
}

output "db_port" {
  description = "Puerto de RDS PostgreSQL"
  value       = aws_db_instance.postgres.port
}

output "db_master_secret_arn" {
  description = "ARN del secreto tesis/<modelo>/db-master (JSON con username, password, host y port)"
  value       = aws_secretsmanager_secret.db_master.arn
}

output "db_security_group_id" {
  description = "ID del security group de RDS PostgreSQL"
  value       = aws_security_group.rds.id
}

output "cache_primary_endpoint" {
  description = "Hostname del nodo primario de ElastiCache"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "cache_port" {
  description = "Puerto de ElastiCache"
  value       = aws_elasticache_replication_group.redis.port
}

output "cache_security_group_id" {
  description = "ID del security group de ElastiCache"
  value       = aws_security_group.cache.id
}

output "ecs_cluster_name" {
  description = "Nombre del clúster ECS del modelo"
  value       = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  description = "ARN del clúster ECS del modelo"
  value       = aws_ecs_cluster.this.arn
}

output "tasks_security_group_id" {
  description = "ID del security group de las tareas ECS"
  value       = aws_security_group.tasks.id
}

output "execution_role_arn" {
  description = "ARN del rol de ejecución de las tareas ECS, con sus políticas ya asociadas"
  value       = aws_iam_role.ecs_execution.arn

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution,
    aws_iam_role_policy.ecs_execution_secrets,
  ]
}

output "log_group_name" {
  description = "Nombre del log group de CloudWatch de las tareas ECS"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "secret_key_secret_arn" {
  description = "ARN del secreto tesis/<modelo>/secret-key (SECRET_KEY del backend)"
  value       = aws_secretsmanager_secret.secret_key.arn
}

output "first_superuser_password_secret_arn" {
  description = "ARN del secreto tesis/<modelo>/first-superuser-password (FIRST_SUPERUSER_PASSWORD del backend)"
  value       = aws_secretsmanager_secret.first_superuser_password.arn
}

output "first_superuser_email" {
  description = "Email del superusuario inicial (FIRST_SUPERUSER del backend)"
  value       = var.first_superuser_email
}

output "secrets_prefix" {
  description = "Prefijo de nombre de los secretos del modelo. El rol de ejecución puede leer todos los secretos con este prefijo"
  value       = local.secrets_prefix
}

output "registros_bucket" {
  description = "Bucket de registros de las validaciones del modelo"
  value       = aws_s3_bucket.registros.bucket
}
