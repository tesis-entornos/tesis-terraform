region      = "us-east-2"
aws_profile = "tf-efimero"
account_id  = "398846004421"
modelo      = "efimero"

compartida_account_id = "582621604637"

github_connection_name = "tesis-entornos-efimeros"
github_connection_arn  = "arn:aws:codeconnections:us-east-2:398846004421:connection/58ee0b88-bab3-4517-ac5d-8f6252faa4b5"
importar_conexion      = false

buildspecs_bucket = "tesis-entornos-buildspecs-582621604637"
buildspecs_folder = "main"

webhook_head_ref_pattern = "^refs/heads/(release|hotfix)/c[0-9]+-[0-9]+$"

# Paso 3 (disparo): sin permisos de despliegue ni secreto del superusuario (pasos 4 y 5).
permisos_despliegue_compartido = false
secreto_superusuario           = false

# Serialización por entorno: cada build espera (sondeo cada 15 s, hasta 60 min) a los builds de su
# misma rama que arrancaron antes; el timeout cubre la espera más el despliegue.
permisos_serializacion = true
timeout_minutos        = 120

descripcion_destino = "en entornos efímeros"
descripcion_disparo = "en cada push a release/c<N>-<n> o hotfix/c<N>-<n>"

# Fuentes secundarias por proyecto: entorno/ de tesis-terraform fijado a un commit (actualizar cuando
# cambie entorno/) y el repo de CD del otro servicio en main (su tag.json: imagen de producción).
# El tag.json de main del propio repo sale del clon completo de la principal (profundidad 0).
git_clone_depth_principal = 0

fuentes_secundarias = {
  backend = [
    { source_identifier = "terraform", repo = "tesis-terraform", version = "56afcc0ba505f4a527adf35392b934598aafbe12" },
    { source_identifier = "frontend_cd_main", repo = "tesis-frontend-cd", version = "main" },
  ]
  frontend = [
    { source_identifier = "terraform", repo = "tesis-terraform", version = "56afcc0ba505f4a527adf35392b934598aafbe12" },
    { source_identifier = "backend_cd_main", repo = "tesis-backend-cd", version = "main" },
  ]
}
