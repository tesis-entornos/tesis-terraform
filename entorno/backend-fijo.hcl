# Sin key: cada entorno tiene su propio state. Se pasa en el init:
#   terraform init -backend-config=backend-fijo.hcl -backend-config="key=entornos/<slug>/terraform.tfstate"
bucket  = "tesis-entornos-tfstate-491265021424"
region  = "us-east-2"
profile = "tf-fijo"
