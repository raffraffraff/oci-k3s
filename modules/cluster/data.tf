resource "random_password" "k3s_token" {
  length  = 55
  special = false
}

data "cloudinit_config" "k3s_server_tpl" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/k3s-install-server.sh", {
      k3s_version            = var.k3s_version,
      k3s_subnet             = var.k3s_subnet,
      k3s_token              = random_password.k3s_token.result,
      is_k3s_server          = true,
      disable_ingress        = var.disable_ingress,
      compartment_ocid       = var.compartment_ocid,
      availability_domain    = var.availability_domain,
      k3s_url                = var.kubeapi_lb_ip_address,
      k3s_tls_san            = var.kubeapi_lb_ip_address,
      install_longhorn       = var.install_longhorn,
      longhorn_release       = var.longhorn_release,
      k3s_datastore_endpoint = var.k3s_datastore_endpoint,
      k3s_controller_args    = var.k3s_controller_args,
    })
  }
}

data "oci_core_instance_pool_instances" "k3s_servers_instances" {
  depends_on = [
    oci_core_instance_pool.k3s_servers,
  ]
  compartment_id   = var.compartment_ocid
  instance_pool_id = oci_core_instance_pool.k3s_servers.id
}

data "oci_core_instance" "k3s_servers_instances_ips" {
  count       = var.k3s_server_pool_size
  instance_id = data.oci_core_instance_pool_instances.k3s_servers_instances.instances[count.index].id
}

