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
