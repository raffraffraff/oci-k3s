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
  type    = string
  default = "staging"
}

variable "cluster_name" {
  type = string
}

variable "arm_image_id" {
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

variable "server_boot_volume_size_gb" {
  type        = number
  default     = 50
  description = "Boot volume size in GB for each k3s server node. OCI Always Free gives 200GB total block storage."
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

variable "kubeapi_lb_id" {
  type = string
}

variable "kubeapi_lb_ip_address" {
  type = string
}

variable "ingress_nlb_id" {
  type = string
}

variable "ingress_nlb_ip_address" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "node_ingress_nsg_id" {
  type = string
}

variable "ingress_nsg_id" {
  type = string
}

variable "k3s_server_pool_size" {
  type    = number
  default = 2
}

variable "disable_ingress" {
  type    = bool
  default = false
}

variable "install_longhorn" {
  type    = bool
  default = true
}

variable "k3s_datastore_endpoint" {
  type        = string
  default     = ""
  description = "Optional external datastore endpoint for k3s (MySQL/Postgres). Example: mysql://user:pw@tcp(host:3306)/k3s?parseTime=true&loc=Local"
}

variable "k3s_controller_args" {
  type = list(string)
  default = [
    "--kube-controller-manager-arg=--node-monitor-period=10s",
    "--kube-controller-manager-arg=--node-monitor-grace-period=2m",
  ]
  description = "List of kube-controller-manager args to pass to k3s server. Use --kube-controller-manager-arg= prefix (k3s v1.29+). Note: --sync-period and --pod-eviction-timeout were removed in Kubernetes 1.24/1.29."
}

variable "longhorn_release" {
  type    = string
  default = "v1.11.2"
}
