# Repositorios ECR de las imágenes del prototipo. Las cuentas de los modelos solo pueden hacer pull.

resource "aws_ecr_repository" "this" {
  for_each = var.ecr_repositories

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
}

data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid    = "PullDesdeCuentasDeModelos"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [for id in var.pull_account_ids : "arn:aws:iam::${id}:root"]
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
  }
}

resource "aws_ecr_repository_policy" "this" {
  for_each = aws_ecr_repository.this

  repository = each.value.name
  policy     = data.aws_iam_policy_document.ecr_pull.json
}
