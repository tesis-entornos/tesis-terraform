# Secreto con un token de GitHub para que los builds escriban en los repos tesis-backend-cd y
# tesis-frontend-cd. Terraform crea solo el contenedor del secreto: el valor (JSON con username y
# token) se carga a mano, fuera de Terraform, para que no quede en el state.

resource "aws_secretsmanager_secret" "github_cd" {
  name                    = "tesis/compartida/github-cd"
  description             = "Token de GitHub para escribir en los repos tesis-backend-cd y tesis-frontend-cd (username y token); el valor se carga a mano, fuera de Terraform"
  recovery_window_in_days = 0
}
