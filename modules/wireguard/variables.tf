variable "region" {
  type = string
}

variable "vcn_cidr" {
  type        = string
  description = "VCN CIDR block — used in client AllowedIPs for split tunnelling"
}

variable "availability_domain" {
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

variable "private_subnet_id" {
  type        = string
  description = "Private subnet ID for the Wireguard instance"
}

variable "wireguard_nsg_id" {
  type        = string
  description = "NSG ID for the Wireguard instance"
}

variable "wireguard_port" {
  type        = string
  default     = "51820"
  description = "UDP port Wireguard listens on"
}

variable "wg_clients" {
  type        = list(string)
  default     = ["client1"]
  description = "List of Wireguard client names to pre-generate configs for"
}

variable "wg_client_bucket_name" {
  type        = string
  default     = "wireguard-client-configs"
  description = "Name of the Object Storage bucket where Wireguard client configs are uploaded"
}

variable "compute_shape" {
  type    = string
  default = "VM.Standard.E2.1.Micro"
}

variable "public_key_path" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Path to your public workstation SSH key"
}

variable "x86_image_id" {
  type        = string
  description = "OCI image OCID for Ubuntu 24.04 x86 (AMD)"
}

variable "fault_domains" {
  type    = list(any)
  default = ["FAULT-DOMAIN-1", "FAULT-DOMAIN-2", "FAULT-DOMAIN-3"]
}

variable "server_boot_volume_size_gb" {
  type        = number
  default     = 50
  description = "Boot volume size in GB. OCI Always Free gives 200GB total block storage."
}
