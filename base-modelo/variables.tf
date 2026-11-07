variable "region" {
  description = "Región AWS de las cargas del modelo"
  type        = string
}

variable "aws_profile" {
  description = "Perfil AWS local de la cuenta del modelo. null cuando las credenciales vienen del entorno (por ejemplo, CodeBuild)"
  type        = string
  default     = null
}

variable "account_id" {
  description = "ID de la cuenta del modelo. El provider rechaza credenciales de cualquier otra cuenta"
  type        = string
}

variable "modelo" {
  description = "Modelo de la cuenta (fijo / efimero). Valor del tag modelo y nombre de la subzona"
  type        = string
}

variable "tags" {
  description = "Tags adicionales, combinados con los comunes"
  type        = map(string)
  default     = {}
}

variable "compartida_profile" {
  description = "Perfil AWS local de la cuenta compartida, usado solo para la delegación NS. null cuando las credenciales vienen del entorno"
  type        = string
  default     = null
}

variable "compartida_account_id" {
  description = "ID de la cuenta compartida, dueña de la zona raíz. El provider compartida rechaza credenciales de cualquier otra cuenta"
  type        = string
}

variable "parent_domain" {
  description = "Dominio de la zona raíz, en la cuenta compartida"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC del modelo"
  type        = string
}

variable "azs" {
  description = "Zonas de disponibilidad de las subredes, una subred pública y una privada por zona"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR de las subredes públicas (ALB y tareas ECS), en el mismo orden que azs"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.azs)
    error_message = "Tiene que haber un CIDR de subred pública por cada zona de azs."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR de las subredes privadas (RDS y ElastiCache), en el mismo orden que azs"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.azs)
    error_message = "Tiene que haber un CIDR de subred privada por cada zona de azs."
  }
}

variable "backend_port" {
  description = "Puerto del backend en las tareas ECS. El ALB solo puede salir hacia ese puerto dentro de la VPC"
  type        = number
}

variable "db_engine_version" {
  description = "Versión exacta (mayor.minor) de RDS PostgreSQL. Sin actualizaciones automáticas de minor"
  type        = string
}

variable "db_instance_class" {
  description = "Clase de instancia de RDS PostgreSQL"
  type        = string
}

variable "db_allocated_storage" {
  description = "Almacenamiento de RDS PostgreSQL, en GiB"
  type        = number
}

variable "db_username" {
  description = "Usuario maestro de RDS PostgreSQL. La contraseña la genera y guarda RDS en Secrets Manager"
  type        = string
}

variable "cache_engine" {
  description = "Motor de ElastiCache (redis / valkey)"
  type        = string
}

variable "cache_engine_version" {
  description = "Versión mayor.minor del motor de ElastiCache. Sin actualizaciones automáticas de minor"
  type        = string
}

variable "cache_node_type" {
  description = "Tipo de nodo de ElastiCache"
  type        = string
}

variable "first_superuser_email" {
  description = "Email del superusuario inicial del backend. Se expone como output para las capas de entorno"
  type        = string
}
