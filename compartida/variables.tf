variable "region" {
  description = "Región AWS de la capa compartida"
  type        = string
}

variable "aws_profile" {
  description = "Perfil AWS local. null cuando las credenciales vienen del entorno (por ejemplo, CodeBuild)"
  type        = string
  default     = null
}

variable "account_id" {
  description = "ID de la cuenta compartida. El provider rechaza credenciales de cualquier otra cuenta"
  type        = string
}

variable "modelo" {
  description = "Valor del tag modelo"
  type        = string
}

variable "tags" {
  description = "Tags adicionales, combinados con los comunes"
  type        = map(string)
  default     = {}
}

variable "ecr_repositories" {
  description = "Nombres de los repositorios ECR de las imágenes del prototipo"
  type        = set(string)
}

variable "pull_account_ids" {
  description = "Cuentas autorizadas a hacer pull de las imágenes (cuentas de los modelos)"
  type        = list(string)
}

variable "buildspecs_folder" {
  description = "Carpeta del bucket de buildspecs de la que leen los proyectos de build (build-<repo>.yml)"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$", var.buildspecs_folder))
    error_message = "buildspecs_folder es una ruta relativa sin barras al principio ni al final."
  }
}
