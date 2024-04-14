# Quick start
## Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0))
2. Register a domain (you can register a .com for the price of two coffees)
3. Download and install the following:
   - [terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools)
   - [helm](https://helm.sh/docs/intro/install)
   - [jq](https://stedolan.github.io/jq/download)
   - [oci-cli](https://github.com/oracle/oci-cli/releases)

# Oracle Free Tier
This whole setup is opinionated. In my opinion it gets the best out of Oracle's generous "always free" tier:
- 1 VCN (a virtual network, like AWS VPC)
- 1 standard Load Balancer (I couldn't launch a Network LB on the free tier)
- 4x VMs that each have 1 Ampere (ARM) CPU, 6GB memory and 50GB disk

## Quick notes on Load Balancers
You can use one Load Balancer and one Network Load Balancer on the free tier.
- Network Load Balancer will be public, used for http (80), https (443) and kubeapi (6443)
- Load Balancer will be private, used internally by the cluster nodes to reach the kubeapi

## Quick notes on Network Security
- Security Lists apply to all VNICs in the VCN. We will use that to allow ssh (22) access from our home IP address
- Network Security Groups only apply where they are attached (eg: VNICs, instances)
- All load balaancers can use Network Security Group

There are other always-free resources (databases, object storage etc) but this project does not use them yet.

# Terraform?
This project contains two modules:
- network: deploys VCN, security groups and rules, load balancers etc
- cluster: deploys instance pools for k3s server(s) and workers

# k3s
Huh, this project says `k0s`, wtf? Well, I honestly had too many issues with k0s so I dropped it for now.

## Cluster setup
- 1x server
- 3x workers
- Longhorn (CSI)
- Traefic ingress controller (installed automatically, using Helm)
- Metrics Server (installed automatically, using kubectl apply)

## TODO:
To make it easier to deploy real stuff to the cluster, we still need:
- cert-manager
- external-dns

The biggest issue I have with simply auto-installing these two is that you might want to use HTTPS01 or DNS01 ACME challenges. If you use the latter, you might want to use your own DNS provider. Personally, I use Cloudflare for a bunch of stuff, so that's what I'm using. But there may not be much point in adding all that junk to this project, except maybe in a separate directory. 

# Usage
## Create an end.auto.tfvars file...
The contents of this file will be specific to you. Here's what I've got in mine (with fake details of course):
```
compartment_ocid = "ocid1.tenancy.oc1..aaaaaaaaffdnionfsfnseifonvosfn32g4i3no6ih9gewenewowntio32nos"
tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaaffdnionfsfnseifonvosfn32g4i3no6ih9gewenewowntio32nos"
user_ocid        = "ocid1.user.oc1..aaaaaaaabkc6lfmneesonfoinesiofnefiegbesuifbui3br3u69wet9wbt3"
fingerprint      = "1a:fe:ed:42:ba:5a:2b:91:aa:25:f9:4a:dd:8c:f6:96"
private_key_path = "/home/raffraffraff/.oci/oci_api_key.pem"
public_key_path  = "/home/raffraffraff/.ssh/id_ed25519.pub"
region           = "eu-amsterdam-1"

# Network config
availability_domain = "qhym:eu-amsterdam-1-AD-1"

# Cluster config
cluster_name     = "mylovelycluster"
os_image_id      = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaa72byfaddfn2wkdhhtgb7c7jjh5jfvri63vumfrafo2tvhdsny3pq"
```
 
## Apply terraform
There's more to it than this, but basically...
```
terraform init
terraform plan
terraform apply
```

## Copy the kubeconfig from the server
When you terraform apply finishes, terraform will output a bunch of IP addresses (yeah, these are fake):
```
nlb_ip_address = "151.183.24.123"
servers_ips = [
  "151.182.123.14",
]
workers_ips = [
  "83.23.175.22",
  "151.181.208.130",
  "134.211.73.19",
]
```

So you just need to copy the `/etc/rancher/k3s/k3s.yaml` from the server to your machine and update its `server:` address to that of the `nlb_ip_address`. Example:
```
scp ubuntu@151.182.123.14:/etc/rancher/k3s/k3s.yaml /tmp/
sed -i '/server:/ s/127.0.0.1/123.123.123.123/'
```

You can test it right away by running:
```
export KUBECONFIG=/tmp/k3s.yaml
kubectl get nodes
```

If that worked, then you can generate a new `~/.kube/config` file with this trick:
```
export KUBECONFIG=/tmp/k3s.yaml:~/.kube/config
kubectl config view --flatten
```

If the output looks good, pipe it to `~/.kube/config`
