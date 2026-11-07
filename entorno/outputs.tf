output "database_name" {
  description = "Base de datos lógica del entorno en el RDS del modelo"
  value       = local.database_name
}

output "files_bucket" {
  description = "Bucket de archivos del entorno"
  value       = aws_s3_bucket.files.bucket
}

output "target_group_arn" {
  description = "ARN del target group del backend"
  value       = aws_lb_target_group.backend.arn
}

output "origin_fqdn" {
  description = "Nombre de origen del backend en el ALB (destino de CloudFront)"
  value       = local.origin_fqdn
}

output "task_definition_arn" {
  description = "ARN de la task definition del backend"
  value       = aws_ecs_task_definition.backend.arn
}

output "service_name" {
  description = "Nombre del servicio ECS del backend"
  value       = aws_ecs_service.backend.name
}

output "task_role_arn" {
  description = "ARN del rol de tarea del backend"
  value       = aws_iam_role.task.arn
}

output "frontend_bucket" {
  description = "Bucket con los archivos estáticos del frontend del entorno"
  value       = aws_s3_bucket.frontend.bucket
}

output "cloudfront_distribution_id" {
  description = "ID de la distribución de CloudFront del entorno (para invalidaciones)"
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_domain_name" {
  description = "Nombre DNS de la distribución de CloudFront"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "public_fqdn" {
  description = "Nombre público del entorno (frontend y /api/*)"
  value       = local.public_fqdn
}
