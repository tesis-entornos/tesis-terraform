provider "aws" {
  profile             = var.aws_profile
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.common_tags
  }
}

# Certificado de CloudFront: tiene que estar en us-east-1.
provider "aws" {
  alias               = "us_east_1"
  profile             = var.aws_profile
  region              = "us-east-1"
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.common_tags
  }
}

# Cuenta compartida: solo para el registro NS de delegación en la zona raíz.
provider "aws" {
  alias               = "compartida"
  profile             = var.compartida_profile
  region              = "us-east-2"
  allowed_account_ids = [var.compartida_account_id]

  default_tags {
    tags = local.common_tags
  }
}
