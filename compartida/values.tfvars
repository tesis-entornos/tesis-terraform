region      = "us-east-2"
aws_profile = "tf-compartida"
account_id  = "582621604637"
modelo      = "compartida"

ecr_repositories = ["tesis-backend", "tesis-frontend"]

pull_account_ids = [
  "491265021424", # tesis-fijo
  "398846004421", # tesis-efimero
]

buildspecs_folder = "main"
