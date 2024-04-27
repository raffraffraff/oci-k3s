resource "oci_core_vcn" "default_oci_core_vcn" {
  cidr_block     = var.oci_core_vcn_cidr
  compartment_id = var.compartment_ocid
  display_name   = "Default OCI core vcn"
  dns_label      = var.oci_core_vcn_dns_label
}

resource "oci_core_subnet" "default_oci_core_subnet10" {
  cidr_block        = var.oci_core_subnet_cidr10
  compartment_id    = var.compartment_ocid
  display_name      = "${var.oci_core_subnet_cidr10} (default) OCI core subnet"
  dns_label         = var.oci_core_subnet_dns_label10
  route_table_id    = oci_core_vcn.default_oci_core_vcn.default_route_table_id
  vcn_id            = oci_core_vcn.default_oci_core_vcn.id
  security_list_ids = [oci_core_default_security_list.default_security_list.id]
}

resource "oci_core_subnet" "oci_core_subnet11" {
  cidr_block        = var.oci_core_subnet_cidr11
  compartment_id    = var.compartment_ocid
  display_name      = "${var.oci_core_subnet_cidr11} OCI core subnet"
  dns_label         = var.oci_core_subnet_dns_label11
  route_table_id    = oci_core_vcn.default_oci_core_vcn.default_route_table_id
  vcn_id            = oci_core_vcn.default_oci_core_vcn.id
  security_list_ids = [oci_core_default_security_list.default_security_list.id]
}

resource "oci_core_internet_gateway" "default_oci_core_internet_gateway" {
  compartment_id = var.compartment_ocid
  display_name   = "Internet Gateway Default OCI core vcn"
  enabled        = "true"
  vcn_id         = oci_core_vcn.default_oci_core_vcn.id
}

resource "oci_core_default_route_table" "default_oci_core_default_route_table" {
  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.default_oci_core_internet_gateway.id
  }
  manage_default_resource_id = oci_core_vcn.default_oci_core_vcn.default_route_table_id
}

resource "oci_core_default_security_list" "default_security_list" {
  compartment_id             = var.compartment_ocid
  manage_default_resource_id = oci_core_vcn.default_oci_core_vcn.default_security_list_id

  display_name = "Default security list"
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = 1 # icmp
    source   = var.my_public_ip_cidr

    description = "Allow icmp from  ${var.my_public_ip_cidr}"

  }

  ingress_security_rules {
    protocol = 6 # tcp
    source   = var.my_public_ip_cidr

    description = "Allow SSH from ${var.my_public_ip_cidr}"

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.oci_core_vcn_cidr

    description = "Allow all from vcn subnet"
  }

}

resource "oci_identity_dynamic_group" "compute_dynamic_group" {
  compartment_id = var.tenancy_ocid
  description    = "Dynamic group which contains all instance in this compartment"
  matching_rule  = "All {instance.compartment.id = '${var.compartment_ocid}'}"
  name           = "Compute_Dynamic_Group"
}

resource "oci_identity_policy" "compute_dynamic_group_policy" {
  compartment_id = var.compartment_ocid
  description    = "Policy to allow dynamic group ${oci_identity_dynamic_group.compute_dynamic_group.name} to read instance-family and compute-management-family in the compartment"
  name           = "Compute_To_Oci_Api_Policy"
  statements = [
    "allow dynamic-group ${oci_identity_dynamic_group.compute_dynamic_group.name} to read instance-family in compartment id ${var.compartment_ocid}",
    "allow dynamic-group ${oci_identity_dynamic_group.compute_dynamic_group.name} to read compute-management-family in compartment id ${var.compartment_ocid}"
  ]
}

