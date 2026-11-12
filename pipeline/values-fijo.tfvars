region      = "us-east-2"
aws_profile = "tf-fijo"
account_id  = "491265021424"
modelo      = "fijo"

compartida_account_id = "582621604637"

github_connection_name = "tesis-entornos-fijos"
github_connection_arn  = "arn:aws:codeconnections:us-east-2:491265021424:connection/6ca7b4c2-59bb-4607-83ce-4f41f9933ae3"
importar_conexion      = false

buildspecs_bucket = "tesis-entornos-buildspecs-582621604637"
buildspecs_folder = "main"

compartido_distribution_id = "E81Q8P6E3KKR"

webhook_head_ref_pattern = "^refs/heads/dev$"

permisos_despliegue_compartido = true
secreto_superusuario           = true

descripcion_destino = "en el entorno compartido del fijo"
descripcion_disparo = "en cada push a dev"
