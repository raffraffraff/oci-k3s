variable "compartment_ocid" {
  type = string
}

variable "availability_domain" {
  type = string
}

variable "private_subnet_id" {
  type        = string
  description = "Private subnet ID in which the MySQL DB System will be placed"
}

variable "mysql_admin_username" {
  type    = string
  default = "k3s_admin"
}

variable "mysql_admin_password" {
  type        = string
  sensitive   = true
  description = "Admin password for the MySQL HeatWave instance"
}

variable "mysql_db_name" {
  type    = string
  default = "k3s"
}

variable "mysql_shape" {
  type        = string
  default     = "MySQL.Free"
  description = "Shape for the MySQL DB System. MySQL.Free is Always Free eligible."
}

variable "mysql_heatwave_shape" {
  type        = string
  default     = "HeatWave.Free"
  description = "Shape for the HeatWave cluster nodes. HeatWave.Free is Always Free eligible."
}

variable "mysql_data_storage_gb" {
  type        = number
  default     = 50
  description = "Data storage in GB for the MySQL DB System (minimum 50 for free shape)"
}

variable "display_name" {
  type    = string
  default = "k3s-mysql-heatwave"
}

variable "customer_contacts" {
  type    = list(string)
  default = []
}