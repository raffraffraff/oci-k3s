# These must be provided in env.auto.tfvars
variable "compartment_ocid" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "public_key_path" {}
variable "cluster_name" {}
variable "arm_image_id" {}
variable "x86_image_id" {}
variable "region" {}

variable "wireguard_port" {
  type        = string
  description = "Wireguard UDP port"
  default     = "51820"
}

variable "wg_clients" {
  type        = list(string)
  default     = []
  description = "List of Wireguard client names to pre-generate configs for"
}

# These have safe and sensible defaults
variable "k3s_server_pool_size" {
  default = 1
}

# MySQL HeatWave inputs
variable "mysql_admin_username" {
  type    = string
  default = "k3s_admin"
}

variable "mysql_admin_password" {
  type      = string
  sensitive = true
}

variable "customer_contacts" {
  type = list(string)
}
