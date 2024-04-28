locals {
  public_ingress_rules = {
    http = {
      source   = "0.0.0.0/0"
      port     = 80
    }
    https = {
      source   = "0.0.0.0/0"
      port     = 443
    }
    kubeapi = {
      source   = var.my_public_ip_cidr
      port     = 6443
    }
  }
}

# Public NLB
resource "oci_network_load_balancer_network_load_balancer" "k3s_public_lb" {
  compartment_id             = var.compartment_ocid
  display_name               = "K3S Public Network Load Balancer"
  subnet_id                  = oci_core_subnet.oci_core_subnet11.id
  network_security_group_ids = [oci_core_network_security_group.public_nlb.id]

  is_private                     = false
  is_preserve_source_destination = false
}

# Backend Sets
resource "oci_network_load_balancer_backend_set" "this" {
  for_each                 = local.public_ingress_rules
  name                     = "k3s_${each.key}_backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = true

  health_checker {
    protocol = "TCP"
    port     = each.value.port
  }
}

# Listeners
resource "oci_network_load_balancer_listener" "this" {
  for_each                 = local.public_ingress_rules
  default_backend_set_name = oci_network_load_balancer_backend_set.this[each.key].name
  name                     = "k3s_${each.key}_listener"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  port                     = each.value.port
  protocol                 = "TCP"
}

# Security Group
resource "oci_core_network_security_group" "public_nlb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.default_oci_core_vcn.id
  display_name   = "K3S Public Network Load Balancer Security Group"
}

# Rules
resource "oci_core_network_security_group_security_rule" "public" {
  for_each                  = local.public_ingress_rules
  network_security_group_id = oci_core_network_security_group.public_nlb.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow ${each.key} from ${each.value.source}"

  source      = each.value.source
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = each.value.port
      min = each.value.port
    }
  }
}
