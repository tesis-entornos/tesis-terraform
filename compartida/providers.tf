provider "aws" {
  profile = "tf-compartida"
  region  = "us-east-2"

  default_tags {
    tags = {
      modelo = "compartida"
    }
  }
}
