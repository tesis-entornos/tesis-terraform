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

descripcion_destino = "en entornos efímeros"
descripcion_disparo = "en cada push a release/c<N>-<n> o hotfix/c<N>-<n>"
