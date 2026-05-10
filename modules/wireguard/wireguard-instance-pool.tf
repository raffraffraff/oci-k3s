resource "oci_core_instance_pool" "wireguard" {
  display_name              = "wireguard"
  compartment_id            = var.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.wireguard_configuration.id

  placement_configurations {
    availability_domain = var.availability_domain
    primary_subnet_id   = var.private_subnet_id
    fault_domains       = var.fault_domains
  }

  size = 2

}
