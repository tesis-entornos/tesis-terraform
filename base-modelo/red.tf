# VPC del modelo: subredes públicas (ALB y tareas ECS) y privadas (RDS y ElastiCache) en dos zonas.
# Sin NAT Gateway, sin VPC endpoints y sin IPv6: las tareas salen a internet con IP pública.

locals {
  # Una entrada por zona, con la letra de la zona como clave (a, b).
  subnets = {
    for i, az in var.azs : substr(az, -1, 1) => {
      az           = az
      public_cidr  = var.public_subnet_cidrs[i]
      private_cidr = var.private_subnet_cidrs[i]
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.modelo}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-igw"
  }
}

# La IP pública de las tareas la asigna ECS (assign_public_ip), no la subred.
resource "aws_subnet" "public" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.value.az
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.modelo}-publica-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.subnets

  vpc_id            = aws_vpc.this.id
  availability_zone = each.value.az
  cidr_block        = each.value.private_cidr

  tags = {
    Name = "${var.modelo}-privada-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-rt-publica"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Solo la ruta local de la VPC: sin salida a internet.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-rt-privada"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
