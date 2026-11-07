region      = "us-east-2"
aws_profile = "tf-fijo"
account_id  = "491265021424"
modelo      = "fijo"

compartida_profile    = "tf-compartida"
compartida_account_id = "582621604637"

parent_domain = "tesis-entornos.click"

vpc_cidr             = "10.0.0.0/16"
azs                  = ["us-east-2a", "us-east-2b"]
public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

backend_port = 8000

db_engine_version    = "18.6"
db_instance_class    = "db.t4g.micro"
db_allocated_storage = 20
db_username          = "postgres"
