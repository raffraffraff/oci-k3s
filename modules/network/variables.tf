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

variable "vcn_dns_label" {
  type    = string
  default = "defaultvcn"
}

variable "private_subnet_dns_label" {
  type    = string
  default = "privatesubnet"
}

variable "public_subnet_dns_label" {
  type    = string
  default = "publicsubnet"
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "my_public_ip_cidr" {
  type        = string
  description = "My public IP as a /32 CIDR, used to lock down SSH and Wireguard in the security list"
}

variable "wireguard_port" {
  type        = string
  description = "Wireguard UDP port"
}
