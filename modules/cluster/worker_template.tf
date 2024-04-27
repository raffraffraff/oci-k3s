resource "oci_core_instance_configuration" "k3s_worker_template" {

  compartment_id = var.compartment_ocid
  display_name   = "k3s worker configuration"

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
        subnet_id        = var.workers_subnet_id
        nsg_ids          = [var.workers_http_nsg_id]
      }

      display_name = "k3s worker template"

      metadata = {
        "ssh_authorized_keys" = file(var.public_key_path)
        "user_data"           = data.cloudinit_config.k3s_worker_tpl.rendered
      }

      shape = var.compute_shape
      shape_config {
        memory_in_gbs = "6"
        ocpus         = "1"
      }
      source_details {
        image_id    = var.os_image_id
        source_type = "image"
      }
    }
  }
}
