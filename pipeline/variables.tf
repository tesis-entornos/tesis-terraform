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
  description = "ID de la distribución de CloudFront del entorno compartido (output cloudfront_distribution_id de entorno/). Solo con permisos_despliegue_compartido"
  type        = string
  default     = null

  validation {
    condition     = !var.permisos_despliegue_compartido || var.compartido_distribution_id != null
    error_message = "compartido_distribution_id es obligatorio con permisos_despliegue_compartido = true."
  }
}

variable "github_connection_arn" {
  description = "ARN de la conexión de GitHub (github_connection_name), para la política del rol y el import"
  type        = string
}

variable "importar_conexion" {
  description = "Si el plan importa la conexión (github_connection_arn): true en el primer apply del modelo, false cuando ya está en el state"
  type        = bool
}

variable "webhook_head_ref_pattern" {
  description = "Regex de HEAD_REF del webhook: las ramas de los repos de CD cuyo push dispara el despliegue"
  type        = string
}

variable "permisos_despliegue_compartido" {
  description = "Si el rol tiene los permisos para desplegar en el entorno compartido del modelo (ECS, S3, CloudFront, ECR, registros)"
  type        = bool
}

variable "secreto_superusuario" {
  description = "Si los proyectos reciben FIRST_SUPERUSER_PASSWORD (Secrets Manager) y el rol puede leer ese secreto"
  type        = bool
}

variable "descripcion_destino" {
  description = "Parte de la descripción de los proyectos: a dónde despliegan"
  type        = string
}

variable "descripcion_disparo" {
  description = "Parte de la descripción de los proyectos: qué los dispara"
  type        = string
}

variable "fuentes_secundarias" {
  description = "Fuentes secundarias de los proyectos de despliegue (clave backend / frontend): repos de tesis-entornos por la misma conexión, con source_identifier, repo, versión (rama o commit SHA) y profundidad del clon (git_clone_depth, default 1; 0: clon completo). No puede incluir el repo de la fuente principal"
  type = map(list(object({
    source_identifier = string
    repo              = string
    version           = string
    git_clone_depth   = optional(number, 1)
  })))
  default = {}

  validation {
    condition     = alltrue([for k, fs in var.fuentes_secundarias : contains(["backend", "frontend"], k) && alltrue([for f in fs : can(regex("^[A-Za-z0-9_]{1,128}$", f.source_identifier)) && f.repo != "tesis-${k}-cd" && f.git_clone_depth >= 0])])
    error_message = "Las claves son backend / frontend; source_identifier solo admite letras, números y guion bajo (hasta 128); el repo de CD del propio proyecto no puede ser fuente secundaria; y git_clone_depth es 0 o más."
  }
}

variable "fuentes_secundarias_cierre" {
  description = "Fuentes secundarias de los proyectos de cierre (proyectos_cierre), con la misma forma y reglas que fuentes_secundarias"
  type = map(list(object({
    source_identifier = string
    repo              = string
    version           = string
    git_clone_depth   = optional(number, 1)
  })))
  default = {}

  validation {
    condition     = alltrue([for k, fs in var.fuentes_secundarias_cierre : contains(["backend", "frontend"], k) && alltrue([for f in fs : can(regex("^[A-Za-z0-9_]{1,128}$", f.source_identifier)) && f.repo != "tesis-${k}-cd" && f.git_clone_depth >= 0])])
    error_message = "Las claves son backend / frontend; source_identifier solo admite letras, números y guion bajo (hasta 128); el repo de CD del propio proyecto no puede ser fuente secundaria; y git_clone_depth es 0 o más."
  }
}

variable "git_clone_depth_principal" {
  description = "Profundidad del clon de la fuente principal (repo de CD). 1: solo el commit del disparo; 0: clon completo, con origin/main (para leer su tag.json)"
  type        = number
  default     = 1
}

variable "permisos_serializacion" {
  description = "Si el rol puede listar y leer los builds de los proyectos del modelo (serialización por entorno: cada build espera a los de su misma rama que arrancaron antes)"
  type        = bool
  default     = false
}

variable "timeout_minutos" {
  description = "Timeout de los builds de despliegue, en minutos (incluye la espera de la serialización)"
  type        = number
  default     = 60

  validation {
    condition     = var.timeout_minutos >= 5 && var.timeout_minutos <= 2160
    error_message = "timeout_minutos tiene que estar entre 5 y 2160 (límite de CodeBuild)."
  }
}

variable "rol_administrador" {
  description = "Si el rol de despliegue tiene AdministratorAccess (efímero: corre Terraform de entorno/ en una cuenta aislada; diferencia declarada con producción)"
  type        = bool
  default     = false
}

variable "proyectos_cierre" {
  description = "Si el modelo tiene los proyectos de cierre (efímero: destruyen el entorno de una rama de versión al mergear o cerrar su PR hacia main-efimero). Usan el rol de despliegue y requieren rol_administrador (la política inline no cubre sus log groups)"
  type        = bool
  default     = false

  validation {
    condition     = !var.proyectos_cierre || var.rol_administrador
    error_message = "proyectos_cierre = true requiere rol_administrador = true."
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
