# These must be provided in env.auto.tfvars
variable "compartment_ocid" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key_path" {}
variable "public_key_path" {}
variable "availability_domain" {}
variable "cluster_name" {}
variable "os_image_id" {}
variable "region" {}

# These have safe and sensible defaults
variable "k3s_server_pool_size" {
  default = 1
}

variable "k3s_worker_pool_size" {
  default = 2
}
