resource "oci_core_instance_pool" "k3s_servers" {
  display_name              = "k3s-servers"
  compartment_id            = var.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.k3s_server_template.id

  placement_configurations {
    availability_domain = var.availability_domain
    primary_subnet_id   = var.workers_subnet_id
    fault_domains       = var.fault_domains
  }

  size = var.k3s_server_pool_size

  load_balancers {
    backend_set_name = "k3s_http_backend"
    load_balancer_id = var.public_nlb_id
    port             = 80
    vnic_selection   = "PrimaryVnic"
  }

  load_balancers {
    backend_set_name = "k3s_https_backend"
    load_balancer_id = var.public_nlb_id
    port             = 443
    vnic_selection   = "PrimaryVnic"
  }

  load_balancers {
    backend_set_name = "k3s_kubeapi_backend"
    port             = 6443
    load_balancer_id = var.public_nlb_id 
    vnic_selection   = "PrimaryVnic"
  }

  load_balancers {
    backend_set_name = "K3s__kube_api_backend_set"
    port             = 6443
    load_balancer_id = var.private_lb_id
    vnic_selection   = "PrimaryVnic"
  }
}

resource "oci_core_instance_pool" "k3s_workers" {
  display_name              = "k3s-workers"
  compartment_id            = var.compartment_ocid
  instance_configuration_id = oci_core_instance_configuration.k3s_worker_template.id

  placement_configurations {
    availability_domain = var.availability_domain
    primary_subnet_id   = var.workers_subnet_id
    fault_domains       = var.fault_domains
  }

  size = var.k3s_worker_pool_size

  load_balancers {
    backend_set_name = "k3s_http_backend"
    load_balancer_id = var.public_nlb_id
    port             = 80
    vnic_selection   = "PrimaryVnic"
  }

  load_balancers {
    backend_set_name = "k3s_https_backend"
    load_balancer_id = var.public_nlb_id
    port             = 443
    vnic_selection   = "PrimaryVnic"
  }

  depends_on = [
    resource.oci_core_instance_pool.k3s_servers
  ]
}
