locals {
  base = data.terraform_remote_state.base.outputs

  # Prefijo de nombres de los recursos del entorno: <modelo>-<slug>
  name = "${var.modelo}-${var.slug}"

  backend_port  = 8000
  database_name = "app_${replace(var.slug, "-", "_")}"

  subzone_name = data.aws_route53_zone.subzone.name
  origin_fqdn  = "${var.slug}-origin.${local.subzone_name}"
  public_fqdn  = "${var.slug}.${local.subzone_name}"

  common_tags = merge(
    {
      modelo  = var.modelo
      entorno = var.slug
    },
    var.tags
  )
}
