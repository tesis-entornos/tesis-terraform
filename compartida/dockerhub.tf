# Secreto con las credenciales de Docker Hub para los builds (evita el límite de pulls anónimos).
# Terraform crea solo el contenedor del secreto: el valor (JSON con username y token) se carga a
# mano, fuera de Terraform, para que no quede en el state.

resource "aws_secretsmanager_secret" "dockerhub" {
  name                    = "tesis/compartida/dockerhub"
  description             = "Credenciales de Docker Hub para los builds (username y token); el valor se carga a mano, fuera de Terraform"
  recovery_window_in_days = 0
}
