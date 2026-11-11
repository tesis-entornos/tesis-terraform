variable "region" {
  description = "Región AWS de la cuenta del modelo"
  type        = string
}

variable "aws_profile" {
  description = "Perfil AWS local. null cuando las credenciales vienen del entorno (por ejemplo, CodeBuild)"
  type        = string
  default     = null
}

variable "account_id" {
  description = "ID de la cuenta del modelo. El provider rechaza credenciales de cualquier otra cuenta"
  type        = string
}

variable "modelo" {
  description = "Modelo de la cuenta (fijo / efimero). Valor del tag modelo y parte del nombre de los proyectos"
  type        = string
}

variable "tags" {
  description = "Tags adicionales, combinados con los comunes"
  type        = map(string)
  default     = {}
}

variable "github_connection_name" {
  description = "Nombre de la conexión de CodeConnections con GitHub de la cuenta, creada desde la consola e importada"
  type        = string
}

variable "buildspecs_bucket" {
  description = "Bucket de buildspecs de la cuenta compartida (da lectura a las cuentas de los modelos)"
  type        = string
}

variable "buildspecs_folder" {
  description = "Carpeta del bucket de buildspecs de la que leen los proyectos (desplegar-<modelo>.yml)"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$", var.buildspecs_folder))
    error_message = "buildspecs_folder es una ruta relativa sin barras al principio ni al final."
  }
}

variable "compartida_account_id" {
  description = "ID de la cuenta compartida, dueña de los repositorios ECR de las imágenes"
  type        = string
}

variable "compartido_distribution_id" {
  description = "ID de la distribución de CloudFront del entorno compartido (output cloudfront_distribution_id de entorno/)"
  type        = string
}
