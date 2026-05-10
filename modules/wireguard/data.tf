data "cloudinit_config" "wireguard_tpl" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/files/wireguard-install.sh", {
      wireguard_port   = var.wireguard_port,
      wg_clients       = var.wg_clients,
      bucket_name      = var.wg_client_bucket_name,
      bucket_namespace = data.oci_objectstorage_namespace.this.namespace,
      vcn_cidr         = var.vcn_cidr,
    })
  }
}

data "oci_core_instance_pool_instances" "wireguard" {
  depends_on = [
    oci_core_instance_pool.wireguard,
  ]
  compartment_id   = var.compartment_ocid
  instance_pool_id = oci_core_instance_pool.wireguard.id
}

data "oci_core_instance" "wireguard" {
  count       = length(data.oci_core_instance_pool_instances.wireguard.instances)
  instance_id = data.oci_core_instance_pool_instances.wireguard.instances[count.index].id
}