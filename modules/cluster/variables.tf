variable "region" {
  type = string
}

variable "availability_domain" {
  type = string
}

variable "tenancy_ocid" {
}

variable "compartment_ocid" {
  type = string
}

variable "environment" {
  type = string
  default = "staging"
}

variable "cluster_name" {
  type = string
}

variable "os_image_id" {
  type = string
}

variable "k3s_version" {
  type    = string
  default = "latest"
}

variable "k3s_subnet" {
  type    = string
  default = "default_route_table"
}

variable "fault_domains" {
  type    = list(any)
  default = ["FAULT-DOMAIN-1", "FAULT-DOMAIN-2", "FAULT-DOMAIN-3"]
}

variable "public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Path to your public workstation SSH key"
}

variable "compute_shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "public_lb_shape" {
  type    = string
  default = "flexible"
}

variable "oci_identity_dynamic_group_name" {
  type        = string
  default     = "Compute_Dynamic_Group"
  description = "Dynamic group which contains all instance in this compartment"
}

variable "oci_identity_policy_name" {
  type        = string
  default     = "Compute_To_Oci_Api_Policy"
  description = "Policy to allow dynamic group, to read OCI api without auth"
}

variable "oci_core_vcn_dns_label" {
  type    = string
  default = "defaultvcn"
}

variable "oci_core_subnet_dns_label10" {
  type    = string
  default = "defaultsubnet10"
}

variable "oci_core_subnet_dns_label11" {
  type    = string
  default = "defaultsubnet11"
}

variable "oci_core_vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "oci_core_subnet_cidr10" {
  type    = string
  default = "10.0.0.0/24"
}

variable "oci_core_subnet_cidr11" {
  type    = string
  default = "10.0.1.0/24"
}

variable "ingress_controller_http_nodeport" {
  type    = number
  default = 30080
}

variable "ingress_controller_https_nodeport" {
  type    = number
  default = 30443
}

variable "private_lb_id" {
  type    = string
}

variable "private_lb_ip_address" {
  type    = string
}

variable "public_nlb_id" {
  type    = string
}

variable "public_nlb_ip_address" {
  type    = string
}

variable "workers_subnet_id" {
  type    = string
}

variable "workers_http_nsg_id" {
  type    = string
}

variable "servers_kubeapi_nsg_id" {
  type    = string
}

variable "k3s_server_pool_size" {
  type    = number
  default = 1
}

variable "k3s_worker_pool_size" {
  type    = number
  default = 3
}

variable "disable_ingress" {
  type    = bool
  default = false
}

variable "ingress_controller" {
  type    = string
  default = "default"
  validation {
    condition     = contains(["default", "nginx"], var.ingress_controller)
    error_message = "Supported ingress controllers are: default, nginx"
  }
}

variable "nginx_ingress_release" {
  type    = string
  default = "v1.5.1"
}

variable "install_longhorn" {
  type    = bool
  default = true
}

variable "longhorn_release" {
  type    = string
  default = "v1.4.2"
}

variable "expose_kubeapi" {
  type    = bool
  default = true
}
