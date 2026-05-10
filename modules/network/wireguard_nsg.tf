resource "oci_core_network_security_group" "wireguard_nsg" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "Wireguard NSG"
}

resource "oci_core_network_security_group_security_rule" "wireguard_udp" {
  network_security_group_id = oci_core_network_security_group.wireguard_nsg.id
  direction                 = "INGRESS"
  protocol                  = 17 # udp
  description               = "Allow Wireguard UDP from anywhere"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  udp_options {
    destination_port_range {
      min = tonumber(var.wireguard_port)
      max = tonumber(var.wireguard_port)
    }
  }
}

resource "oci_core_network_security_group_security_rule" "wireguard_ssh" {
  network_security_group_id = oci_core_network_security_group.wireguard_nsg.id
  direction                 = "INGRESS"
  protocol                  = 6 # tcp
  description               = "Allow SSH from my public IP"
  source                    = var.my_public_ip_cidr
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}
