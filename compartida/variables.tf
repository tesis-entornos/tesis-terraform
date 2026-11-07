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
