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

webhook_head_ref_pattern = "^refs/heads/release/c[0-9]+-[0-9]+$"

# Sin permisos de despliegue en la compartida. Secreto del superusuario para la suite Playwright
# (tesis/efimero/first-superuser-password, creado por base-modelo/).
permisos_despliegue_compartido = false
secreto_superusuario           = true

# Serialización por entorno: cada build espera (sondeo cada 15 s, hasta 60 min) a los builds de su
# misma rama que arrancaron antes; el timeout cubre la espera más el despliegue.
permisos_serializacion = true
timeout_minutos        = 180

# El rol corre Terraform de entorno/ en una cuenta aislada: AdministratorAccess (diferencia con
# producción, declarada).
rol_administrador = true

descripcion_destino = "en entornos efímeros"
descripcion_disparo = "en cada push a release/c<N>-<n> o hotfix/c<N>-<n>"

# Fuentes secundarias por proyecto: entorno/ de tesis-terraform fijado a un commit (actualizar cuando
# cambie entorno/) y el repo de CD del otro servicio en main (su tag.json: imagen de producción).
# El tag.json de main del propio repo sale del clon completo de la principal (profundidad 0).
git_clone_depth_principal = 0

fuentes_secundarias = {
  backend = [
    { source_identifier = "terraform", repo = "tesis-terraform", version = "47032ae0df2c7b9ccbd9b7930565a157ef535ed1" },
    { source_identifier = "frontend_cd_main", repo = "tesis-frontend-cd", version = "main" },
  ]
  frontend = [
    { source_identifier = "terraform", repo = "tesis-terraform", version = "47032ae0df2c7b9ccbd9b7930565a157ef535ed1" },
    { source_identifier = "backend_cd_main", repo = "tesis-backend-cd", version = "main" },
  ]
}

# Proyectos de cierre (tesis-efimero-cerrar-<x>): al mergear o cerrar el PR de una rama de versión
# hacia main-efimero, destruir-efimero.yml decide si destruye su entorno. Mismo terraform que el
# despliegue (actualizar los dos juntos) y el main del otro repo de CD con clon completo (el
# buildspec lista sus ramas).
proyectos_cierre = true

fuentes_secundarias_cierre = {
  backend = [
    { source_identifier = "terraform", repo = "tesis-terraform", version = "47032ae0df2c7b9ccbd9b7930565a157ef535ed1" },
    { source_identifier = "frontend_cd_main", repo = "tesis-frontend-cd", version = "main", git_clone_depth = 0 },
  ]
  frontend = [
    { source_identifier = "terraform", repo = "tesis-terraform", version = "47032ae0df2c7b9ccbd9b7930565a157ef535ed1" },
    { source_identifier = "backend_cd_main", repo = "tesis-backend-cd", version = "main", git_clone_depth = 0 },
  ]
}
