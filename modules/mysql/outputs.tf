output "mysql_private_ip" {
  value = local.mysql_private_ip
}

output "k3s_datastore_endpoint" {
  value     = local.k3s_datastore_endpoint
  sensitive = true
}

output "mysql_db_system_id" {
  value = oci_mysql_mysql_db_system.k3s_mysql.id
}
