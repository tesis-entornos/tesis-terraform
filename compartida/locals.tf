locals {
  tfstate_bucket_name = "tesis-entornos-tfstate-${var.account_id}"

  common_tags = merge(
    {
      modelo = var.modelo
    },
    var.tags
  )
}
