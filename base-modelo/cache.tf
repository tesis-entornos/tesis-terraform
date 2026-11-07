# ElastiCache del modelo, compartido por todos los entornos, en las subredes privadas.
# Un solo nodo, sin modo clúster, sin failover y sin snapshots: es una caché regenerable.
# Sin cifrado en tránsito ni auth_token: el acceso queda limitado a la VPC por el security group.

locals {
  # Parameter group por defecto de la familia, con modo clúster deshabilitado (ej. default.redis7).
  cache_parameter_group = "default.${var.cache_engine}${split(".", var.cache_engine_version)[0]}"
}

resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.modelo}-redis"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = {
    Name = "${var.modelo}-redis"
  }
}

resource "aws_security_group" "cache" {
  name        = "${var.modelo}-cache"
  description = "ElastiCache del modelo ${var.modelo}: 6379 solo desde la VPC"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-cache"
  }
}

resource "aws_vpc_security_group_ingress_rule" "cache_redis" {
  security_group_id = aws_security_group.cache.id
  description       = "Redis desde la VPC"
  ip_protocol       = "tcp"
  from_port         = 6379
  to_port           = 6379
  cidr_ipv4         = var.vpc_cidr

  tags = {
    Name = "${var.modelo}-cache-redis"
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.modelo}-redis"
  description          = "Cache del modelo ${var.modelo}, un nodo sin modo cluster"

  engine                     = var.cache_engine
  engine_version             = var.cache_engine_version
  auto_minor_version_upgrade = false
  node_type                  = var.cache_node_type
  parameter_group_name       = local.cache_parameter_group
  port                       = 6379

  num_cache_clusters         = 1
  automatic_failover_enabled = false
  multi_az_enabled           = false

  subnet_group_name  = aws_elasticache_subnet_group.redis.name
  security_group_ids = [aws_security_group.cache.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false

  snapshot_retention_limit = 0
  apply_immediately        = true

  tags = {
    Name = "${var.modelo}-redis"
  }
}
