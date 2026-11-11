# Bucket de registros del modelo: cada validación deja su registro persistente, agrupado por
# corrida (la unidad experimental). Los registros se conservan hasta el final del experimento:
# sin lifecycle, sin versionado y sin force_destroy (un destroy con registros adentro falla).

resource "aws_s3_bucket" "registros" {
  bucket        = "tesis-${var.modelo}-registros-${var.account_id}"
  force_destroy = false

  tags = {
    Name = "${var.modelo}-registros"
  }
}

resource "aws_s3_bucket_public_access_block" "registros" {
  bucket = aws_s3_bucket.registros.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# SSE-S3 explícito (es el default de S3, así queda declarado).
resource "aws_s3_bucket_server_side_encryption_configuration" "registros" {
  bucket = aws_s3_bucket.registros.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
