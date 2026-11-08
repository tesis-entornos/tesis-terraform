# Bucket de buildspecs (publicados desde el repo tesis-buildspecs) y conexión con GitHub
# para los proyectos de CodeBuild.

resource "aws_s3_bucket" "buildspecs" {
  bucket = local.buildspecs_bucket_name
}

resource "aws_s3_bucket_versioning" "buildspecs" {
  bucket = aws_s3_bucket.buildspecs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "buildspecs" {
  bucket = aws_s3_bucket.buildspecs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Las cuentas de los modelos leen los buildspecs; los roles de CodeBuild de cada cuenta
# necesitan además s3:GetObject en su propia política IAM.
data "aws_iam_policy_document" "buildspecs_read" {
  statement {
    sid    = "LecturaDesdeCuentasDeModelos"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for id in var.pull_account_ids : "arn:aws:iam::${id}:root"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.buildspecs.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "buildspecs" {
  bucket = aws_s3_bucket.buildspecs.id
  policy = data.aws_iam_policy_document.buildspecs_read.json

  # El public access block tiene que existir antes que la política.
  depends_on = [aws_s3_bucket_public_access_block.buildspecs]
}

# Queda en PENDING hasta autorizarla a mano en la consola.
resource "aws_codeconnections_connection" "github" {
  name          = "tesis-github"
  provider_type = "GitHub"
}
