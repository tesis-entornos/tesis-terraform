# Subzona del modelo, delegada desde la zona raíz, y certificados wildcard de la subzona.

data "aws_route53_zone" "parent" {
  provider = aws.compartida

  name         = var.parent_domain
  private_zone = false
}

resource "aws_route53_zone" "subzone" {
  name    = local.subzone_name
  comment = "Subzona del modelo ${var.modelo}, delegada desde ${var.parent_domain}"
}

# Solo cambia el último campo del SOA (TTL de respuestas negativas) a 60 s.
# El resto queda con los valores por defecto de Route 53.
resource "aws_route53_record" "subzone_soa" {
  zone_id         = aws_route53_zone.subzone.zone_id
  name            = local.subzone_name
  type            = "SOA"
  ttl             = 900
  allow_overwrite = true
  records         = ["${aws_route53_zone.subzone.primary_name_server}. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 60"]
}

resource "aws_route53_record" "delegation" {
  provider = aws.compartida

  zone_id = data.aws_route53_zone.parent.zone_id
  name    = local.subzone_name
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.subzone.name_servers
}

resource "aws_acm_certificate" "us_east_1" {
  provider = aws.us_east_1

  domain_name       = "*.${local.subzone_name}"
  validation_method = "DNS"
  key_algorithm     = "RSA_2048"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate" "regional" {
  domain_name       = "*.${local.subzone_name}"
  validation_method = "DNS"
  key_algorithm     = "RSA_2048"

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  validation_us_east_1 = one(aws_acm_certificate.us_east_1.domain_validation_options)
  validation_regional  = one(aws_acm_certificate.regional.domain_validation_options)
}

# Mismo dominio en la misma cuenta: ACM pide el mismo registro en las dos regiones,
# así que alcanza con un solo CNAME. La precondición de la validación regional lo verifica.
resource "aws_route53_record" "cert_validation" {
  zone_id         = aws_route53_zone.subzone.zone_id
  name            = local.validation_us_east_1.resource_record_name
  type            = local.validation_us_east_1.resource_record_type
  ttl             = 60
  records         = [local.validation_us_east_1.resource_record_value]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "us_east_1" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.us_east_1.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]

  depends_on = [aws_route53_record.delegation]
}

resource "aws_acm_certificate_validation" "regional" {
  certificate_arn         = aws_acm_certificate.regional.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]

  depends_on = [aws_route53_record.delegation]

  lifecycle {
    precondition {
      condition = (
        local.validation_regional.resource_record_name == local.validation_us_east_1.resource_record_name &&
        local.validation_regional.resource_record_value == local.validation_us_east_1.resource_record_value
      )
      error_message = "El registro de validación del certificado regional no coincide con el de us-east-1: hace falta un segundo CNAME."
    }
  }
}
