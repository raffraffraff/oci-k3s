locals {
  private_ingress_ports = ["80", "443"]
}

# Private Load Balancer — internal kubeapi endpoint for cluster nodes
resource "oci_load_balancer_load_balancer" "private_kubeapi_lb" {
  lifecycle {
    ignore_changes = [network_security_group_ids]
  }

  compartment_id = var.compartment_ocid
  display_name   = "K3S Private Kubeapi LB"
  shape          = "flexible"
  subnet_ids     = [oci_core_subnet.public.id]

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
  load_balancer_id         = oci_load_balancer_load_balancer.private_kubeapi_lb.id
  name                     = "K3s__kube_api_listener"
  port                     = 6443
  protocol                 = "TCP"
}

resource "oci_load_balancer_backend_set" "k3s_kube_api_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = 6443
  }
  load_balancer_id = oci_load_balancer_load_balancer.private_kubeapi_lb.id
  name             = "K3s__kube_api_backend_set"
  policy           = "ROUND_ROBIN"
}

# NSG on node VNICs — allows 80/443 from the public ingress NLB
resource "oci_core_network_security_group" "node_ingress_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "K3S Node Ingress NSG"
}

resource "oci_core_network_security_group_security_rule" "node_ingress" {
  for_each                  = toset(local.private_ingress_ports)
  network_security_group_id = oci_core_network_security_group.node_ingress_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow port ${each.value} from public ingress NLB NSG"

  source      = oci_core_network_security_group.public_ingress_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = each.value
      min = each.value
    }
  }
}
