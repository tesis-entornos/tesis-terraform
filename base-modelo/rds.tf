# RDS PostgreSQL del modelo, compartido por todos los entornos, en las subredes privadas.
# Sin base inicial: las bases lógicas de cada entorno las crea la tarea de migraciones.
# Sin backups ni snapshot final: los datos del prototipo se pueden regenerar.

resource "aws_db_subnet_group" "postgres" {
  name       = "${var.modelo}-postgres"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = {
    Name = "${var.modelo}-postgres"
  }
}

resource "aws_security_group" "rds" {
  name        = "${var.modelo}-rds"
  description = "RDS PostgreSQL del modelo ${var.modelo}: 5432 solo desde la VPC"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.modelo}-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL desde la VPC"
  ip_protocol       = "tcp"
  from_port         = 5432
  to_port           = 5432
  cidr_ipv4         = var.vpc_cidr

  tags = {
    Name = "${var.modelo}-rds-postgres"
  }
}

resource "aws_db_instance" "postgres" {
  identifier                 = "${var.modelo}-postgres"
  engine                     = "postgres"
  engine_version             = var.db_engine_version
  auto_minor_version_upgrade = false
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  storage_type               = "gp3"
  storage_encrypted          = true
  multi_az                   = false
  publicly_accessible        = false

  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  username                    = var.db_username
  manage_master_user_password = true

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true

  tags = {
    Name = "${var.modelo}-postgres"
  }
}
