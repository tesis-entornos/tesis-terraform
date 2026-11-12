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
