#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y wireguard ufw
# python3-venv needed to avoid pip/debian urllib3 conflict on 24.04 (PEP 668)
apt-get install --no-install-recommends -y python3 python3-venv

# Fix journal size
echo "SystemMaxUse=100M"      >> /etc/systemd/journald.conf
echo "SystemMaxFileSize=100M" >> /etc/systemd/journald.conf
systemctl restart systemd-journald

# Install OCI CLI (instance principal auth — no credentials needed)
python3 -m venv /opt/oci-cli
/opt/oci-cli/bin/pip install oci-cli
export PATH="/opt/oci-cli/bin:$PATH"
export OCI_CLI_AUTH=instance_principal

# Detect the primary network interface (name varies by OCI shape/image: ens3, enp1s0, eth0...)
PRIMARY_IFACE=$(ip -4 route show default | awk '{print $5}' | head -n1)

# Get this instance's IPs
PRIVATE_IP=$(ip -4 addr show "$PRIMARY_IFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
PUBLIC_IP=$(curl -sf https://ifconfig.me/ip)

# Get instance display name from OCI metadata (used as bucket path prefix: wireguard1/, wireguard2/, ...)
INSTANCE_NAME=$(curl -sf -H "Authorization: Bearer Oracle" \
  http://169.254.169.254/opc/v2/instance/ \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['displayName'])")

# Generate server keys
WG_PRIVATE_KEY=$(wg genkey)
WG_PUBLIC_KEY=$(echo "$WG_PRIVATE_KEY" | wg pubkey)
echo "$WG_PRIVATE_KEY" > /etc/wireguard/server_private.key
echo "$WG_PUBLIC_KEY"  > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

# Write base server config
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.8.0.1/24
PrivateKey = $WG_PRIVATE_KEY
PostUp   = iptables -I INPUT 1 -p udp --dport ${wireguard_port} -j ACCEPT
PostUp   = iptables -I FORWARD 1 -i wg0 -j ACCEPT
PostUp   = iptables -I FORWARD 1 -o wg0 -j ACCEPT
PostUp   = iptables -t nat -I POSTROUTING -o $PRIMARY_IFACE -j MASQUERADE
PreDown  = iptables -D INPUT -p udp --dport ${wireguard_port} -j ACCEPT
PreDown  = iptables -D FORWARD -i wg0 -j ACCEPT
PreDown  = iptables -D FORWARD -o wg0 -j ACCEPT
PreDown  = iptables -t nat -D POSTROUTING -o $PRIMARY_IFACE -j MASQUERADE
ListenPort = ${wireguard_port}
EOF

# Generate a keypair + client config for each client, then upload to Object Storage
mkdir -p /etc/wireguard/clients
CLIENT_OCTET=2

upload_to_bucket() {
  local object_name="$1"
  local file_path="$2"
  # --force overwrites any existing object — safe on re-deploy, new keys replace old ones
  oci os object put \
    --namespace "${bucket_namespace}" \
    --bucket-name "${bucket_name}" \
    --name "$object_name" \
    --file "$file_path" \
    --force
  echo "Uploaded $object_name to bucket ${bucket_name}"
}

%{ for client in wg_clients ~}
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
echo "$CLIENT_PRIVATE_KEY" > /etc/wireguard/clients/${client}_private.key
echo "$CLIENT_PUBLIC_KEY"  > /etc/wireguard/clients/${client}_public.key
chmod 600 /etc/wireguard/clients/${client}_private.key

# Add peer to server wg0.conf
cat >> /etc/wireguard/wg0.conf <<EOF

[Peer]
# ${client}
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.8.0.$CLIENT_OCTET/32
EOF

# Write client config
cat > /etc/wireguard/clients/${client}.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.8.0.$CLIENT_OCTET/24
DNS = 1.1.1.1
PostUp = ip route add $PUBLIC_IP/32 via \$(ip -4 route show default | awk '{print \$3}' | head -1) dev \$(ip -4 route show default | awk '{print \$5}' | head -1) 2>/dev/null || true
PreDown = ip route del $PUBLIC_IP/32 2>/dev/null || true

[Peer]
PublicKey = $WG_PUBLIC_KEY
AllowedIPs = 10.8.0.0/24, ${vcn_cidr}
Endpoint = $PUBLIC_IP:${wireguard_port}
PersistentKeepalive = 25
EOF

upload_to_bucket "$INSTANCE_NAME/${client}.conf" "/etc/wireguard/clients/${client}.conf"
CLIENT_OCTET=$((CLIENT_OCTET + 1))
%{ endfor ~}

# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
sysctl -p

# Firewall
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
ufw allow 22/tcp
ufw allow ${wireguard_port}/udp
ufw --force enable
ufw reload

# Disable sshd reverse DNS lookups (prevents 30s delay when connecting from VPN IPs)
echo "UseDNS no" >> /etc/ssh/sshd_config
systemctl reload ssh || true  # not active during cloud-init (socket-activated); ignore error

# Start Wireguard
systemctl enable wg-quick@wg0.service
systemctl start wg-quick@wg0.service

echo "=== Wireguard status ==="
wg show wg0
echo "=== Client configs in bucket ${bucket_name} ==="
oci os object list --namespace "${bucket_namespace}" --bucket-name "${bucket_name}" \
  --query 'data[].{name:name,"size":"size"}' --output table
