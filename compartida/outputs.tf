output "tfstate_bucket_name" {
  description = "Nombre del bucket de states de la cuenta compartida"
  value       = aws_s3_bucket.tfstate.bucket
}

output "tfstate_bucket_arn" {
  description = "ARN del bucket de states de la cuenta compartida"
  value       = aws_s3_bucket.tfstate.arn
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR, por nombre"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "buildspecs_bucket" {
  description = "Nombre del bucket de buildspecs"
  value       = aws_s3_bucket.buildspecs.bucket
}

output "buildspecs_bucket_arn" {
  description = "ARN del bucket de buildspecs"
  value       = aws_s3_bucket.buildspecs.arn
}

output "github_connection_arn" {
  description = "ARN de la conexión con GitHub (PENDING hasta autorizarla en la consola)"
  value       = aws_codeconnections_connection.github.arn
}
