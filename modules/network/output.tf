output "default_vcn_route_table_id" {
  value = oci_core_vcn.default_oci_core_vcn.default_route_table_id
}

output "default_vcn_id" {
  value = oci_core_vcn.default_oci_core_vcn.id
}

output "default_vcn_security_list_id" {
  value = oci_core_vcn.default_oci_core_vcn.default_security_list_id
}

output "nlb_id" {
  value = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
}

output "nlb_ip_address" {
  value = [for interface in oci_network_load_balancer_network_load_balancer.k3s_public_lb.ip_addresses : interface.ip_address if interface.is_public == true][0]
}

output "lb_id" {
  value = oci_load_balancer_load_balancer.k3s_private_lb.id
}

output "lb_ip_address" {
  value = oci_load_balancer_load_balancer.k3s_private_lb.ip_address_details[0].ip_address
}

output "workers_subnet_id" {
  value = oci_core_subnet.default_oci_core_subnet10.id
}

output "workers_http_nsg_id" {
  value = oci_core_network_security_group.lb_to_instances_http.id
}

output "servers_kubeapi_nsg_id" {
  value = oci_core_network_security_group.lb_to_instances_kubeapi.id
}
