# Network Outputs
output "nlb_ip_address" {
  value = module.network.nlb_ip_address
}

output "workers_ips" {
  value = module.cluster.k3s_workers_ips
}

output "servers_ips" {
  value = module.cluster.k3s_servers_ips
}
