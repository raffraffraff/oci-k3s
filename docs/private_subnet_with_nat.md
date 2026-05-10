# Hardening the private subnet with NAT routing

## Current state

Both subnets (`10.0.0.0/24` private, `10.0.1.0/24` public) share the default VCN route table,
which has a default route pointing at the Internet Gateway. This means all instances — including
k3s nodes — have direct internet exposure, mitigated only by NSG rules and the default security
list.

The Wireguard instance exists primarily to provide VPN access into the private subnet, but it is
also well-positioned to act as a NAT gateway, eliminating the need for a paid OCI managed NAT
Gateway (which is **not** included in the Always Free tier).

## Target state

```
Internet
    │
    ▼
Internet Gateway
    │
    ├──▶ public subnet (10.0.1.0/24)   ← load balancers only
    │
    └──▶ Wireguard/NAT instance        ← single ingress/egress for private subnet
              │   (private subnet, public IP retained)
              │
              ▼
         private subnet (10.0.0.0/24)  ← k3s nodes, MySQL (no public IPs)
              │
              └── outbound via Wireguard instance MASQUERADE
```

## Prerequisites

Before making these changes, confirm:

1. Wireguard VPN is deployed and reachable from your workstation
2. You can reach the k3s nodes and MySQL instance **through the VPN tunnel**
3. The Wireguard instance has a stable private IP (it will become the subnet's default gateway)

If step 2 is not true, do not proceed — you will lock yourself out of the nodes.

## Implementation steps

### 1. Enable NAT masquerading on the Wireguard instance

The Wireguard install script already enables `ip_forward` and sets up MASQUERADE for the `wg0`
interface. Extend it to also masquerade traffic from the private subnet on `enp1s0`:

```bash
iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o enp1s0 -j MASQUERADE
iptables-save > /etc/iptables/rules.v4          # persist across reboots
apt-get install -y iptables-persistent
```

This can be added to `modules/wireguard/files/wireguard-install.sh` or applied manually first
to test.

### 2. Add a private route table in the network module

In `modules/network/vcn.tf` (or a new `route_tables.tf`), add a dedicated route table for the
private subnet that routes outbound traffic via the Wireguard instance's private IP:

```hcl
resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.this.id
  display_name   = "Private subnet route table (NAT via Wireguard)"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = data.oci_core_private_ips.wireguard.private_ips[0].id
  }
}
```

You will need a data source to look up the Wireguard instance's private IP by its VNIC, or pass
the private IP as an output from the wireguard module and accept it as an input in the network
module.

### 3. Associate the private subnet with the new route table

Update `oci_core_subnet.private` in `modules/network/vcn.tf`:

```hcl
resource "oci_core_subnet" "private" {
  ...
  route_table_id    = oci_core_route_table.private.id   # was: default_route_table_id
  ...
}
```

Add a `moved` block to `modules/network/moved.tf` if the route table association is an in-place
update (it should be — OCI allows changing a subnet's route table without recreation).

### 4. Disable public IPs on k3s nodes

In `modules/cluster/server_template.tf`, change:

```hcl
create_vnic_details {
  assign_public_ip = false          # was: true
  subnet_id        = var.private_subnet_id
  nsg_ids          = [var.ingress_nsg_id, var.node_ingress_nsg_id]
}
```

> ⚠️ This will **destroy and recreate** the instance configuration, which will trigger a rolling
> replacement of all nodes in the instance pool. Plan accordingly.

### 5. Update the security list

Once nodes have no public IPs, the SSH and Wireguard-port ingress rules in the default security
list that are scoped to `var.my_public_ip_cidr` only need to apply to the **public subnet**.
The private subnet's security list can drop those rules entirely. Consider splitting the default
security list into separate ones per subnet at this point.

## Dependency note: module ordering

The network module currently has no knowledge of the Wireguard instance's private IP — that lives
in the wireguard module. To wire the NAT route table up via Terraform (rather than hardcoding an
IP), you will need to either:

- Output the Wireguard private IP from `module.wireguard` and pass it into `module.network` as a
  new variable (creates a dependency: network must be applied *after* wireguard), or
- Use a `terraform_data` / `null_resource` with a local-exec to patch the route table post-deploy

The simplest approach is to accept the private IP as an optional input to the network module
(`wireguard_private_ip`, default `null`) and only create the private route table when it is set.
This keeps the initial deploy working unchanged, and the NAT cutover becomes a second `apply`.
