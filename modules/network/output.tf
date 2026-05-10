output "ingress_nlb_id" {
  value = oci_network_load_balancer_network_load_balancer.public_ingress_nlb.id
}

output "ingress_nlb_ip_address" {
  value = [for interface in oci_network_load_balancer_network_load_balancer.public_ingress_nlb.ip_addresses : interface.ip_address if interface.is_public == true][0]
}

output "kubeapi_lb_id" {
  value = oci_load_balancer_load_balancer.private_kubeapi_lb.id
}

output "kubeapi_lb_ip_address" {
  value = oci_load_balancer_load_balancer.private_kubeapi_lb.ip_address_details[0].ip_address
}

output "private_subnet_id" {
  value = oci_core_subnet.private.id
}

output "ingress_nsg_id" {
  value = oci_core_network_security_group.public_ingress_nsg.id
}

output "node_ingress_nsg_id" {
  value = oci_core_network_security_group.node_ingress_nsg.id
}

output "wireguard_nsg_id" {
  value = oci_core_network_security_group.wireguard_nsg.id
}

output "vcn_cidr" {
  value = oci_core_vcn.this.cidr_block
}