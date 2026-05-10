resource "oci_core_instance_configuration" "k3s_server_template" {

  compartment_id = var.compartment_ocid
  display_name   = "k3s server configuration"

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
        nsg_ids          = [var.ingress_nsg_id, var.node_ingress_nsg_id]
      }

      display_name = "k3s server template"

      metadata = {
        "ssh_authorized_keys" = file(var.public_key_path)
        "user_data"           = data.cloudinit_config.k3s_server_tpl.rendered
      }

      shape = var.compute_shape
      shape_config {
        memory_in_gbs = "12"
        ocpus         = "2"
      }
      source_details {
        image_id                = var.arm_image_id
        source_type             = "image"
        boot_volume_size_in_gbs = var.server_boot_volume_size_gb
      }
    }
  }
}
