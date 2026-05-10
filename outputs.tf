# Network Outputs
output "ingress_nlb_ip_address" {
  value = module.network.ingress_nlb_ip_address
}

output "private_lb_ip_address" {
  value = module.network.kubeapi_lb_ip_address
}

output "servers_ips" {
  value = module.cluster.k3s_servers_ips
}

output "servers_private_ips" {
  value = module.cluster.k3s_servers_private_ips
}

output "wireguard_public_ips" {
  value = module.wireguard.wireguard_public_ips
}

output "wg_client_bucket" {
  description = "Retrieve a client config with: oci os object get --namespace <namespace> --bucket-name <bucket> --name <client>.conf --file ~/<client>.conf"
  value = {
    namespace = module.wireguard.wg_client_bucket_namespace
    bucket    = module.wireguard.wg_client_bucket_name
  }
}
