locals {
  common_tags = merge(
    {
      modelo = var.modelo
    },
    var.tags
  )
}
