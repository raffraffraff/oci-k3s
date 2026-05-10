resource "oci_core_instance_configuration" "wireguard_configuration" {

  compartment_id = var.compartment_ocid
  display_name   = "Wireguard instance configuration"

  instance_details {
    instance_type = "compute"

    launch_details {

      agent_config {
        is_management_disabled = "false"
        is_monitoring_disabled = "false"

        plugins_config {
          desired_state = "DISABLED"
          name          = "Vulnerability Scanning"
        }

        plugins_config {
          desired_state = "ENABLED"
          name          = "Compute Instance Monitoring"
        }

        plugins_config {
          desired_state = "DISABLED"
          name          = "Bastion"
        }
      }

      availability_domain = var.availability_domain
      compartment_id      = var.compartment_ocid

      create_vnic_details {
        assign_public_ip = true
        subnet_id        = var.private_subnet_id
        nsg_ids          = [var.wireguard_nsg_id]
      }

      display_name = "Wireguard instance configuration"

      metadata = {
        "ssh_authorized_keys" = file(var.public_key_path)
        "user_data"           = data.cloudinit_config.wireguard_tpl.rendered
      }

      shape = var.compute_shape
      shape_config {
        memory_in_gbs = "1"
        ocpus         = "1"
      }

      source_details {
        image_id                = var.x86_image_id
        source_type             = "image"
        boot_volume_size_in_gbs = var.server_boot_volume_size_gb
      }
    }
  }
}
