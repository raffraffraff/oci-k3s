terraform {
  backend "oci" {
    bucket               = "terraform-eu-dev"
    namespace            = "axwsgdyoowr8"
    region               = "eu-amsterdam-1"
    key                  = "terraform.tfstate"
    workspace_key_prefix = "env:"
  }
}
