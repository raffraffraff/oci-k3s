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
      k3s_version                       = var.k3s_version,
      k3s_subnet                        = var.k3s_subnet,
      k3s_token                         = random_password.k3s_token.result,
      is_k3s_server                     = true,
      disable_ingress                   = var.disable_ingress,
      ingress_controller                = var.ingress_controller,
      nginx_ingress_release             = var.nginx_ingress_release,
      compartment_ocid                  = var.compartment_ocid,
      availability_domain               = var.availability_domain,
      k3s_url                           = var.private_lb_ip_address
      k3s_tls_san                       = var.private_lb_ip_address
      k3s_tls_san_public                = var.public_nlb_ip_address,
      expose_kubeapi                    = var.expose_kubeapi,
      install_longhorn                  = var.install_longhorn,
      longhorn_release                  = var.longhorn_release,
      ingress_controller_http_nodeport  = var.ingress_controller_http_nodeport,
      ingress_controller_https_nodeport = var.ingress_controller_https_nodeport,
    })
  }
}

data "cloudinit_config" "k3s_worker_tpl" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/k3s-install-agent.sh", {
      k3s_version                       = var.k3s_version,
      k3s_subnet                        = var.k3s_subnet,
      k3s_token                         = random_password.k3s_token.result,
      is_k3s_server                     = false,
      disable_ingress                   = var.disable_ingress,
      k3s_url                           = var.private_lb_ip_address
      install_longhorn                  = var.install_longhorn,
      ingress_controller_http_nodeport  = var.ingress_controller_http_nodeport,
      ingress_controller_https_nodeport = var.ingress_controller_https_nodeport,
    })
  }
}

data "oci_core_instance_pool_instances" "k3s_workers_instances" {
  compartment_id   = var.compartment_ocid
  instance_pool_id = oci_core_instance_pool.k3s_workers.id
}

data "oci_core_instance" "k3s_workers_instances_ips" {
  count       = var.k3s_worker_pool_size
  instance_id = data.oci_core_instance_pool_instances.k3s_workers_instances.instances[count.index].id
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

