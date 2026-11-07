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
