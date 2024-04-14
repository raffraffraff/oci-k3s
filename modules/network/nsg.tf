resource "oci_core_network_security_group" "public_lb_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.default_oci_core_vcn.id
  display_name   = "K3s public LB nsg"

  freeform_tags = {
    "provisioner"           = "terraform"
    "environment"           = var.environment
  }
}

resource "oci_core_network_security_group_security_rule" "allow_http_from_all" {
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow HTTP from all"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_https_from_all" {
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow HTTPS from all"

  source      = "0.0.0.0/0"
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 443
      min = 443
    }
  }
}

resource "oci_core_network_security_group_security_rule" "allow_kubeapi_from_all" {
  network_security_group_id = oci_core_network_security_group.public_lb_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow kubeapi from home IP"

  source      = var.my_public_ip_cidr
  source_type = "CIDR_BLOCK"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 6443
      min = 6443
    }
  }
}

resource "oci_core_network_security_group" "lb_to_instances_http" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.default_oci_core_vcn.id
  display_name   = "Public LB to K3s workers Compute Instances NSG"

  freeform_tags = {
    "provisioner"           = "terraform"
    "environment"           = var.environment
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_to_instances_http" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_http.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow HTTP from all"

  source      = oci_core_network_security_group.public_lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 80
      min = 80
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_to_instances_https" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_http.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow HTTPS from all"

  source      = oci_core_network_security_group.public_lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 443
      min = 443
    }
  }
}

resource "oci_core_network_security_group" "lb_to_instances_kubeapi" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.default_oci_core_vcn.id
  display_name   = "Public LB to K3s master Compute Instances NSG (kubeapi)"

  freeform_tags = {
    "provisioner"           = "terraform"
    "environment"           = var.environment
  }
}

resource "oci_core_network_security_group_security_rule" "nsg_to_instances_kubeapi" {
  network_security_group_id = oci_core_network_security_group.lb_to_instances_kubeapi.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp

  description = "Allow kubeapi access from home IP"

  source      = oci_core_network_security_group.public_lb_nsg.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      max = 6443
      min = 6443
    }
  }
}
