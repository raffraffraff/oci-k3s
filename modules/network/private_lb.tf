locals {
  private_ingress_ports = [ "80", "443", "6443" ]
}

# Private Load Balancer for the K3S nodes
resource "oci_load_balancer_load_balancer" "k3s_private_lb" {
  lifecycle {
    ignore_changes = [network_security_group_ids]
  }

  compartment_id = var.compartment_ocid
  display_name   = "K3S Private Load Balancer"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.oci_core_subnet11.id]

  ip_mode    = "IPV4"
  is_private = true

  shape_details {
    maximum_bandwidth_in_mbps = 10
    minimum_bandwidth_in_mbps = 10
  }
}

# Kubeapi Listener
resource "oci_load_balancer_listener" "k3s_kube_api_listener" {
  default_backend_set_name = oci_load_balancer_backend_set.k3s_kube_api_backend_set.name
  load_balancer_id         = oci_load_balancer_load_balancer.k3s_private_lb.id
  name                     = "K3s__kube_api_listener"
  port                     = 6443
  protocol                 = "TCP"
}


resource "oci_load_balancer_backend_set" "k3s_kube_api_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = 6443
  }
  load_balancer_id = oci_load_balancer_load_balancer.k3s_private_lb.id
  name             = "K3s__kube_api_backend_set"
  policy           = "ROUND_ROBIN"
}

resource "oci_core_network_security_group" "private_lb" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.default_oci_core_vcn.id
  display_name   = "K3S Private Load Balancer Security Group"
}

# Allow a wide range of traffic from public NLB to workers (80 to 9000)
#resource "oci_core_network_security_group_security_rule" "allow_traffic_from_public_nlb" {
#  network_security_group_id = oci_core_network_security_group.private_lb.id
#  direction                 = "INGRESS"
#  protocol                  = 6 # tcp
#
#  description = "Allow port ${each.value} from Public NLB"
#
#  source      = oci_core_network_security_group.public_nlb.id
#  source_type = "NETWORK_SECURITY_GROUP"
#  stateless   = false
#
#  tcp_options {
#    destination_port_range {
#      max = 9000
#      min = 80
#    }
#  }
#}

resource "oci_core_network_security_group_security_rule" "private" {
  for_each                  = toset(local.private_ingress_ports)
  network_security_group_id = oci_core_network_security_group.private_lb.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow port ${each.value} from K3S Public Load Balancer Security Group"

  source      = oci_core_network_security_group.public_nlb.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = each.value
      min = each.value
    }
  }
}
