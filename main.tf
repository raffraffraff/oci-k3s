data "http" "ip" {
  url = "https://ifconfig.me/ip"
}

data "oci_identity_availability_domains" "this" {
  compartment_id = var.tenancy_ocid
}

locals {
  availability_domain = data.oci_identity_availability_domains.this.availability_domains[0].name
}

module "network" {
  source = "./modules/network"

  region            = var.region
  compartment_ocid  = var.compartment_ocid
  tenancy_ocid      = var.tenancy_ocid
  my_public_ip_cidr = join("/", [data.http.ip.response_body, "32"])
  wireguard_port    = var.wireguard_port
}

module "mysql" {
  source = "./modules/mysql"

  compartment_ocid     = var.compartment_ocid
  availability_domain  = local.availability_domain
  private_subnet_id    = module.network.private_subnet_id
  mysql_admin_username = var.mysql_admin_username
  mysql_admin_password = var.mysql_admin_password
  customer_contacts    = var.customer_contacts
}

module "cluster" {
  source = "./modules/cluster"

  region                 = var.region
  availability_domain    = local.availability_domain
  tenancy_ocid           = var.tenancy_ocid
  compartment_ocid       = var.compartment_ocid
  cluster_name           = var.cluster_name
  public_key_path        = var.public_key_path
  arm_image_id           = var.arm_image_id
  ingress_nlb_id         = module.network.ingress_nlb_id
  ingress_nlb_ip_address = module.network.ingress_nlb_ip_address
  kubeapi_lb_id          = module.network.kubeapi_lb_id
  kubeapi_lb_ip_address  = module.network.kubeapi_lb_ip_address
  private_subnet_id      = module.network.private_subnet_id
  node_ingress_nsg_id    = module.network.node_ingress_nsg_id
  ingress_nsg_id         = module.network.ingress_nsg_id
  k3s_datastore_endpoint = module.mysql.k3s_datastore_endpoint

  depends_on = [module.mysql]
}

module "wireguard" {
  source = "./modules/wireguard"

  region              = var.region
  availability_domain = local.availability_domain
  tenancy_ocid        = var.tenancy_ocid
  compartment_ocid    = var.compartment_ocid
  public_key_path     = var.public_key_path
  x86_image_id        = var.x86_image_id
  private_subnet_id   = module.network.private_subnet_id
  wireguard_nsg_id    = module.network.wireguard_nsg_id
  wireguard_port      = var.wireguard_port
  wg_clients          = var.wg_clients
  vcn_cidr            = module.network.vcn_cidr
}
