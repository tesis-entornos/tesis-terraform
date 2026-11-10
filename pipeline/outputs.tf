output "github_connection_arn" {
  description = "ARN de la conexión de CodeConnections con GitHub de la cuenta"
  value       = aws_codeconnections_connection.github.arn
}

output "desplegar_project_names" {
  description = "Nombres de los proyectos de despliegue, por servicio"
  value       = { for k, p in aws_codebuild_project.desplegar : k => p.name }
}
