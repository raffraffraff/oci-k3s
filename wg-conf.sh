#!/bin/bash

WG_JSON=$(terraform output -json wg_client_bucket)
WG_NAMESPACE=$(echo "$WG_JSON" | jq -r '.namespace')
WG_BUCKET=$(echo "$WG_JSON" | jq -r '.bucket')

# List client configs in bucket
echo "=== Client configs in bucket ${WG_BUCKET} ==="
oci os object list --namespace "${WG_NAMESPACE}" --bucket-name "${WG_BUCKET}" \
  --query 'data[].{name:name,"size":"size"}' --output table

read -p "Enter the name of the client config to download and use: " CLIENT_CONFIG
if [[ -n "$CLIENT_CONFIG" ]]; then
  # CLIENT_CONFIG is like "wireguard1/zenbook.conf" — derive a flat local filename
  LOCAL_NAME=$(echo "$CLIENT_CONFIG" | tr '/' '-')
  oci os object get --namespace "${WG_NAMESPACE}" --bucket-name "${WG_BUCKET}" \
        --name "${CLIENT_CONFIG}" --file ~/Downloads/${LOCAL_NAME}
  # Also write a vpn variant with AllowedIPs = 0.0.0.0/0 (full tunnel)
  VPN_NAME=$(echo "$LOCAL_NAME" | sed 's/^[^-]*-/vpn-/')
  cp ~/Downloads/${LOCAL_NAME} ~/Downloads/${VPN_NAME}
  sed -i '/AllowedIPs/ s/.*\(AllowedIPs =\).*/\1 0.0.0.0\/0/' ~/Downloads/${VPN_NAME}
  echo "Downloaded: ~/Downloads/${LOCAL_NAME}"
  echo "Full tunnel: ~/Downloads/${VPN_NAME}"
fi 