# Frontend del entorno: bucket privado con los archivos estáticos, servido por CloudFront con
# OAC. CloudFront es el edge del entorno: /api/* va al ALB de la base (por el nombre de origen
# del entorno) y el resto al bucket, con reescritura de rutas de la SPA a /index.html.
# La publicación de los archivos en el bucket no es parte de esta capa.

locals {
  frontend_bucket_name = "tesis-${local.name}-frontend-${var.account_id}"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# --- Bucket ---------------------------------------------------------------------

resource "aws_s3_bucket" "frontend" {
  bucket        = local.frontend_bucket_name
  force_destroy = true

  tags = {
    Name = "${local.name}-frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${local.name}-frontend"
  description                       = "Acceso de CloudFront al bucket del frontend del entorno ${var.slug}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Solo esta distribución puede leer los objetos.
data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    sid       = "LecturaDesdeCloudFront"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::${local.frontend_bucket_name}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json

  # La política de bloqueo de acceso público tiene que existir antes que la del bucket.
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# --- CloudFront -----------------------------------------------------------------

# Equivalente a la administrada UseOriginCacheControlHeaders, pero sin headers ni cookies en la
# clave: esa incluye Host, y reenviar Host a un origen S3 hace que S3 lo tome como nombre de
# bucket. Con default_ttl = 0, cada objeto se cachea según su propio Cache-Control.
resource "aws_cloudfront_cache_policy" "frontend" {
  name        = "${local.name}-frontend"
  comment     = "Frontend del entorno ${var.slug}: respeta el Cache-Control de cada objeto"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 31536000

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }

    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# Rutas de la SPA (sin extensión en el último segmento) → /index.html. Los archivos
# (/assets/app-1234.js, /favicon.ico) pasan sin cambios. Solo en el comportamiento por defecto:
# /api/* no pasa por esta función.
resource "aws_cloudfront_function" "spa" {
  name    = "${local.name}-spa"
  comment = "Reescribe las rutas de la SPA del entorno ${var.slug} a /index.html"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      var last = uri.substring(uri.lastIndexOf('/') + 1);
      if (last.indexOf('.') === -1) {
        request.uri = '/index.html';
      }
      return request;
    }
  EOT
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = false
  price_class         = "PriceClass_100"
  comment             = "Entorno ${var.slug} del modelo ${var.modelo}"
  default_root_object = "index.html"
  aliases             = [local.public_fqdn]
  wait_for_deployment = true

  origin {
    origin_id                = "s3"
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    origin_id   = "alb"
    domain_name = local.origin_fqdn

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    cache_policy_id        = aws_cloudfront_cache_policy.frontend.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa.arn
    }
  }

  # AllViewerExceptHostHeader: el ALB recibe como Host el nombre de origen del entorno,
  # que es el que matchea su regla en el listener.
  ordered_cache_behavior {
    path_pattern             = "/api/*"
    target_origin_id         = "alb"
    allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods           = ["GET", "HEAD"]
    viewer_protocol_policy   = "redirect-to-https"
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.base.certificate_arn_us_east_1
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name = "${local.name}-cdn"
  }
}

resource "aws_route53_record" "public" {
  zone_id = local.base.zone_id
  name    = local.public_fqdn
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
