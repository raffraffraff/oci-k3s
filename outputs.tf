# Network Outputs
output "public_nlb_ip_address" {
  value = module.network.public_nlb_ip_address
}

output "workers_ips" {
  value = module.cluster.k3s_workers_ips
}

output "servers_ips" {
  value = module.cluster.k3s_servers_ips
}
