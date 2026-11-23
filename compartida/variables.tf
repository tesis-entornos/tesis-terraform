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

variable "github_pr_actor_ids" {
  description = "IDs numéricos de las cuentas de GitHub que pueden disparar builds con eventos de PR (gh api users/<usuario> --jq .id). Con los repos públicos, un PR desde un fork de otra cuenta no dispara builds. Los grupos PUSH no se filtran: un fork no puede pushear a las ramas del repo"
  type        = list(string)

  validation {
    condition     = length(var.github_pr_actor_ids) > 0 && alltrue([for id in var.github_pr_actor_ids : can(regex("^[0-9]+$", id))])
    error_message = "github_pr_actor_ids necesita al menos un ID, y cada uno es numérico (no el login)."
  }
}
