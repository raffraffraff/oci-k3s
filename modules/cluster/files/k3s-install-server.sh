#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Disable netfilter-persistent if somehow active (not present on OCI Ubuntu 24.04, but harmless)
if systemctl is-active --quiet netfilter-persistent 2>/dev/null; then
  systemctl stop --now netfilter-persistent.service
  systemctl disable netfilter-persistent.service
fi

# OCI Ubuntu images have a blanket REJECT rule in iptables that blocks everything not explicitly
# allowed. Open the ports k3s needs before anything tries to use them.
iptables -I INPUT -p tcp --dport 6443 -j ACCEPT  # kubeapi
iptables -I INPUT -p tcp --dport 10250 -j ACCEPT # kubelet metrics
iptables -I INPUT -p udp --dport 8472 -j ACCEPT  # flannel VXLAN
iptables -I INPUT -p tcp --dport 2379 -j ACCEPT  # etcd (unused but harmless)
iptables -I INPUT -p tcp --dport 2380 -j ACCEPT  # etcd peer (unused but harmless)

apt-get update -y
apt-get install -y software-properties-common jq curl
apt-get upgrade -y
# python3-venv needed to avoid pip/debian urllib3 conflict on 24.04 (PEP 668)
apt-get install --no-install-recommends -y python3 python3-venv
python3 -m venv /opt/oci-cli
/opt/oci-cli/bin/pip install oci-cli
export PATH="/opt/oci-cli/bin:$PATH"

# Cap journal size
echo "SystemMaxUse=100M"      >> /etc/systemd/journald.conf
echo "SystemMaxFileSize=100M" >> /etc/systemd/journald.conf
systemctl restart systemd-journald

# ---------- k3s install params ----------

wait_lb() {
  while true; do
    curl --output /dev/null --silent -k https://${k3s_url}:6443 && break
    echo "Waiting for LB..."
    sleep 5
  done
}

export OCI_CLI_AUTH=instance_principal
first_instance=$(oci compute instance list \
  --compartment-id ${compartment_ocid} \
  --availability-domain ${availability_domain} \
  --lifecycle-state RUNNING \
  --sort-by TIMECREATED \
  | jq -r '.data[]|select(."display-name" | endswith("k3s-servers")) | .["display-name"]' \
  | head -n 1)
instance_id=$(curl -s -H "Authorization: Bearer Oracle" -L http://169.254.169.254/opc/v2/instance | jq -r '.displayName')

k3s_install_params=("--tls-san ${k3s_tls_san}")

%{ if k3s_subnet != "default_route_table" }
local_ip=$(ip -4 route ls ${k3s_subnet} | grep -Po '(?<=src )(\S+)')
flannel_iface=$(ip -4 route ls ${k3s_subnet} | grep -Po '(?<=dev )(\S+)')
k3s_install_params+=("--node-ip $local_ip")
k3s_install_params+=("--advertise-address $local_ip")
k3s_install_params+=("--flannel-iface $flannel_iface")
%{ endif }

%{ if disable_ingress }
k3s_install_params+=("--disable traefik")
%{ endif }

%{ if k3s_datastore_endpoint != "" }
k3s_install_params+=("--datastore-endpoint ${k3s_datastore_endpoint}")
%{ endif }

%{ if k3s_controller_args != [] }
%{ for arg in k3s_controller_args }
k3s_install_params+=("${arg}")
%{ endfor }
%{ endif }

INSTALL_PARAMS="$${k3s_install_params[*]}"

%{ if k3s_version == "latest" }
K3S_VERSION=$(curl --silent https://api.github.com/repos/k3s-io/k3s/releases/latest | jq -r '.name')
%{ else }
K3S_VERSION="${k3s_version}"
%{ endif }

if [[ "$first_instance" == "$instance_id" ]]; then
  echo "First instance — cluster init"
  until curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=${k3s_token} sh -s - --cluster-init $INSTALL_PARAMS; do
    echo "k3s did not install correctly, retrying..."
    sleep 2
  done
else
  echo "Joining existing cluster"
  wait_lb
  until curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=${k3s_token} sh -s - --server https://${k3s_url}:6443 $INSTALL_PARAMS; do
    echo "k3s did not install correctly, retrying..."
    sleep 2
  done
fi

%{ if is_k3s_server }
until kubectl get pods -A | grep -q 'Running'; do
  echo "Waiting for k3s to be ready..."
  sleep 5
done

%{ if install_longhorn }
if [[ "$first_instance" == "$instance_id" ]]; then
  apt-get install --no-install-recommends -y open-iscsi util-linux
  systemctl enable --now iscsid.service
  kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/${longhorn_release}/deploy/longhorn.yaml
fi
%{ endif }

%{ endif }
