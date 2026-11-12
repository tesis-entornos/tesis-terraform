# Sin key: cada entorno tiene su propio state. Se pasa en el init:
#   terraform init -backend-config=backend-efimero.hcl -backend-config="key=entornos/<slug>/terraform.tfstate"
bucket  = "tesis-entornos-tfstate-398846004421"
region  = "us-east-2"
profile = "tf-efimero"
