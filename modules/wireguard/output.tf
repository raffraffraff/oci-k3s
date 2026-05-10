output "wireguard_public_ips" {
  description = "Public IP addresses of all Wireguard instances"
  value       = data.oci_core_instance.wireguard[*].public_ip
}

output "wg_client_bucket_name" {
  description = "Object Storage bucket holding Wireguard client configs"
  value       = oci_objectstorage_bucket.wireguard_clients.name
}

output "wg_client_bucket_namespace" {
  description = "Object Storage namespace for the Wireguard client config bucket"
  value       = data.oci_objectstorage_namespace.this.namespace
}
