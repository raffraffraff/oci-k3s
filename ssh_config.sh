#!/bin/bash

PRIVATE_LB=$(terraform output -raw private_lb_ip_address)
SERVER_IPS=$(terraform output -json servers_ips | jq -r 'join(" ")')
SERVER_PRIVATE_IPS=$(terraform output -json servers_private_ips | jq -r 'join(" ")')
WIREGUARD_IPS=$(terraform output -json wireguard_public_ips | jq -r '.[]')

NODE=1
PUBLIC_IP_ARRAY=($SERVER_IPS)
PRIVATE_IP_ARRAY=($SERVER_PRIVATE_IPS)
for IP in $SERVER_IPS; do
PRIVATE_IP=${PRIVATE_IP_ARRAY[$((NODE-1))]}
cat <<EOF
Host k3s${NODE}
  HostName        $IP
  User            ubuntu
  Port            22

Host k3s-tunnel${NODE}
  HostName        $IP
  User            ubuntu
  Port            22
  LocalForward    6443 ${PRIVATE_LB}:6443
  ServerAliveInterval 30
  ExitOnForwardFailure yes
  ControlMaster   auto
  ControlPath     ~/.ssh/ctrl-%r@%h:%p

Host k3s${NODE}-via-wg
  HostName        ${PRIVATE_IP}
  User            ubuntu
  Port            22

Host k3s-tunnel${NODE}-via-wg
  HostName        ${PRIVATE_IP}
  User            ubuntu
  Port            22
  LocalForward    6443 ${PRIVATE_LB}:6443
  ServerAliveInterval 30
  ExitOnForwardFailure yes
  ControlMaster   auto
  ControlPath     ~/.ssh/ctrl-%r@%h:%p

EOF
NODE=$((NODE+1))
done

WG_NODE=1
for WG_IP in $WIREGUARD_IPS; do
cat <<EOF
Host wireguard${WG_NODE}
  HostName        $WG_IP
  User            ubuntu
  Port            22

EOF
WG_NODE=$((WG_NODE+1))
done
