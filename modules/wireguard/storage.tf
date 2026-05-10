data "oci_objectstorage_namespace" "this" {
  compartment_id = var.compartment_ocid
}

resource "oci_objectstorage_bucket" "wireguard_clients" {
  compartment_id = var.compartment_ocid
  namespace      = data.oci_objectstorage_namespace.this.namespace
  name           = var.wg_client_bucket_name
  access_type    = "NoPublicAccess"
  versioning     = "Disabled"

  freeform_tags = {
    "managed-by" = "terraform"
    "purpose"    = "wireguard-client-configs"
  }
}
