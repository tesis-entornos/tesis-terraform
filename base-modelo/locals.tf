locals {
  subzone_name = "${var.modelo}.${var.parent_domain}"

  common_tags = merge(
    {
      modelo  = var.modelo
      entorno = "base"
    },
    var.tags
  )
}
