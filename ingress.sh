#!/bin/bash
# Link: https://docs.nginx.com/nginx-ingress-controller/installation/installation-with-helm/

# Install namespace if it's not there
kubectl get namespaces | grep -q nginx-ingress || kubectl create namespace nginx-ingress

# Add helm repo if it's not there
helm repo list | grep -q nginx-stable || helm repo add nginx-stable https://helm.nginx.com/stable
helm repo update

# Install nginx-ingress helm chart with hostNetwork and status port that won't clash with kube-router
helm upgrade --install nginx-ingress -n nginx-ingress  nginx-stable/nginx-ingress \
	--set controller.hostNetwork=true \
	--set controller.nginxStatus.port=18080
