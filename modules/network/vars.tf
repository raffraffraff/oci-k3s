variable "region" {
  type = string
}

variable "tenancy_ocid" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "environment" {
  type    = string
  default = "staging"
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

variable "unique_tag_key" {
  type    = string
  default = "k3s-provisioner"
}

variable "unique_tag_value" {
  type    = string
  default = "https://github.com/garutilorenzo/k3s-oci-cluster"
}

variable "my_public_ip_cidr" {
  type        = string
  description = "My public ip CIDR"
}

variable "public_lb_shape" {
  type    = string
  default = "flexible"
}

variable "public_load_balancer_name" {
  type    = string
  default = "K3s public LB"
}

variable "k3s_load_balancer_name" {
  type    = string
  default = "k3s internal load balancer"
}
