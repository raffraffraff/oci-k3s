resource "oci_mysql_mysql_db_system" "k3s_mysql" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  subnet_id           = var.private_subnet_id
  shape_name          = var.mysql_shape
  display_name        = var.display_name

  admin_username = var.mysql_admin_username
  admin_password = var.mysql_admin_password

  dynamic "customer_contacts" {
    for_each = var.customer_contacts
    content {
      email = customer_contacts.value
    }
  }

  data_storage_size_in_gb = var.mysql_data_storage_gb

  database_management = "DISABLED"

  deletion_policy {
    automatic_backup_retention = "RETAIN"
    final_backup               = "SKIP_FINAL_BACKUP"
    is_delete_protected        = false
  }
}

# Enable HeatWave on the DB system (1 node is enough for k3s datastore use)
resource "oci_mysql_heat_wave_cluster" "k3s_mysql_heatwave" {
  db_system_id = oci_mysql_mysql_db_system.k3s_mysql.id
  cluster_size = 1
  shape_name   = var.mysql_heatwave_shape
}

locals {
  mysql_private_ip = oci_mysql_mysql_db_system.k3s_mysql.ip_address
  k3s_datastore_endpoint = format(
    "mysql://%s:%s@tcp(%s:3306)/%s?parseTime=true&loc=Local",
    var.mysql_admin_username,
    var.mysql_admin_password,
    local.mysql_private_ip,
    var.mysql_db_name
  )
}
