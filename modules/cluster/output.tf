output "k3s_servers_ips" {
  depends_on = [
    data.oci_core_instance_pool_instances.k3s_servers_instances,
  ]
  value = data.oci_core_instance.k3s_servers_instances_ips.*.public_ip
}

output "k3s_servers_private_ips" {
  depends_on = [
    data.oci_core_instance_pool_instances.k3s_servers_instances,
  ]
  value = data.oci_core_instance.k3s_servers_instances_ips.*.private_ip
}
