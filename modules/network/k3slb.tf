resource "oci_network_load_balancer_network_load_balancer" "k3s_public_lb" {
  compartment_id             = var.compartment_ocid
  display_name               = var.public_load_balancer_name
  subnet_id                  = oci_core_subnet.oci_core_subnet11.id
  network_security_group_ids = [oci_core_network_security_group.public_lb_nsg.id]

  is_private                     = false
  is_preserve_source_destination = false

  freeform_tags = {
    "provisioner"           = "terraform"
    "environment"           = var.environment
  }
}

# HTTP
resource "oci_network_load_balancer_listener" "k3s_http_listener" {
  default_backend_set_name = oci_network_load_balancer_backend_set.k3s_http_backend_set.name
  name                     = "k3s_http_listener"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  port                     = 80
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend_set" "k3s_http_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = 80
  }

  name                     = "k3s_http_backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = true
}

# HTTPS
resource "oci_network_load_balancer_listener" "k3s_https_listener" {
  default_backend_set_name = oci_network_load_balancer_backend_set.k3s_https_backend_set.name
  name                     = "k3s_https_listener"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  port                     = 443
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend_set" "k3s_https_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = 443
  }

  name                     = "k3s_https_backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = true
}

# kube-api

resource "oci_network_load_balancer_listener" "k3s_kubeapi_listener" {
  default_backend_set_name = oci_network_load_balancer_backend_set.k3s_kubeapi_backend_set.name
  name                     = "k3s_kubeapi_listener"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  port                     = 6443
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend_set" "k3s_kubeapi_backend_set" {
  health_checker {
    protocol = "TCP"
    port     = 6443
  }

  name                     = "k3s_kubeapi_backend"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.k3s_public_lb.id
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = true
}
