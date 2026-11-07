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
