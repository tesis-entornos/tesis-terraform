variable "region" {
  description = "Región AWS de la cuenta del modelo"
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
  description = "Modelo de la cuenta (fijo / efimero). Valor del tag modelo"
  type        = string
}

variable "tags" {
  description = "Tags adicionales, combinados con los comunes"
  type        = map(string)
  default     = {}
}

variable "slug" {
  description = "Identificador del entorno: nombres de recursos, subdominio, base de datos y prefijo de caché. Valor del tag entorno"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.slug))
    error_message = "slug solo admite a-z, 0-9 y guiones, con hasta 20 caracteres."
  }
}

variable "corrida" {
  description = "Corrida del experimento (c<N>) a la que pertenece el entorno. Valor del tag corrida; null: sin tag corrida"
  type        = string
  default     = null

  validation {
    condition     = var.corrida == null || can(regex("^c[0-9]+$", var.corrida))
    error_message = "corrida tiene que ser c<N> (por ejemplo, c0) o null."
  }
}

variable "n" {
  description = "Número del entorno dentro del modelo (1 a 99). Define la prioridad de su regla en el listener del ALB (n * 10)"
  type        = number

  validation {
    condition     = floor(var.n) == var.n && var.n >= 1 && var.n <= 99
    error_message = "n tiene que ser un entero entre 1 y 99."
  }
}

variable "backend_image" {
  description = "Imagen del backend referenciada por digest (<registro>/<repo>@sha256:<digest>)"
  type        = string

  validation {
    condition     = can(regex("@sha256:[0-9a-f]{64}$", var.backend_image))
    error_message = "backend_image tiene que ser una referencia por digest (...@sha256:<64 hex>)."
  }
}

variable "project_name" {
  description = "PROJECT_NAME del backend"
  type        = string
}
