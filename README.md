# Quick start
## Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0))
2. Register a domain (you can register a .com for the price of two coffees)
3. Download and install the following:
   - [terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools)
   - [helm](https://helm.sh/docs/intro/install)
   - [k0sctl](https://github.com/k0sproject/k0sctl/releases)
   - [jq](https://stedolan.github.io/jq/download)
   - [oci-cli](https://github.com/oracle/oci-cli/releases)

# Oracle Free Tier
This whole setup is opinionated. In my opinion it gets the best out of Oracle's generous "always free" tier:
- 1 VCN (a virtual network, like AWS VPC)
- 1 standard Load Balancer (I couldn't launch a Network LB on the free tier)
- 4x VMs that each have 1 Ampere (ARM) CPU, 6GB memory and 50GB disk

## Quick notes on Load Balancers
You can only add a single Load Balancer on the free tier, but it supports:
- Multiple backend groups, each with its own protocol/port/health config
- Multiple listeners, each with its own protocol/port/backend config

## Quick notes on Network Security
- Security Lists apply to all VNICs in the VCN
- Network Security Groups apply to selected VNICs (...apparently - I can't select which ones my group uses!)
- The Load Balancer can use Network Security Group

There are other always-free resources (databases, object storage etc) but I have not yet used them yet.

# Terraform?
_For now_ I haven't written the terraform code to create the required infrastructure, but I'll get to that soon

# k0s
[k0s](https://k0sproject.io/) is a Kubernetes distribution that can be launched using a single binary. However, it also supports highly-available clusters, and is fully CNCF compliant.

## Quick notes on k0s and cluster setup
### Turning off metrics-server and konnectivity-server
By default, k0s is a minimally opinionated Kubernetes distro that comes with metrics-server, konnectivity, coredns. However, in my particular setup (no "automatic" Cloud Load Balancer, highly-available control plane with no taints) nothing worked properly until I...
1. Disabled konnectivity-server (it's not needed in this setup)
2. Disabled metrics-server (didn't work, and timed out requests causing every kubectl action to take forever)

### eBPF / Cilium / latest shit?
I really wanted to do this from the start, because I want to use eBPF instead of iptables and kube-proxy. Unfortunately, it's flakey AF right now _in this setup_. I couldn't get Cilium pods to stay up. I don't want to knock Cilium, because this ~is~ _was_ definitely some weird networking quirk of my setup. I'll come back to this!

### Ingress
Ingress allows you to accept traffic into the cluster and direct it to different services based on rules. Ingress itself relies on _some other networking setup_ to let the traffic in. On AWS EKS, it's probably a Load Balancer. But on _this_ cluster, unless you want to install a load balancer controller in your cluster and pay for an additional Load Balancer, you need to do things differently:
- Ingress will run with hostNetwork=true
- The port of the nginx pod will be exposed directly on the node it runs on
- Your Oracle load balancer port 80 listener will sent traffic to a backend group that uses _the port you expose nginx ingress on_

# Steps...
Since I don't have this stuff terraformed yet, here's the list of steps you need to carry out manually.

## DNS
1. Register a domain. I used Cloudflare because their additional features are great
2. Replace all occurrences of "example.com" with your domain in `simple-web-app.yaml` and `k0sctl.yaml`

## OCI steps...
1. Create a VCN
2. Create a Reserved IP address
3. Create a network security group
   - Use the reserved IP
   - Allow all traffic from your home IP: `curl icanhazip.com`
4. Create 4 VMs
   - Ampere (ARM) CPU
   - 6GB memory
   - 50GB disk
   - Ubuntu 20.04
   - Attach the network security group
5. Back up the iptables rules!
6. Allow all traffic from your home IP address:
   - `sudo iptables -I INPUT -p tcp -s 1.2.3.4/32 -j ACCEPT`
8. Create a standard load balancer:
   - Attach Network Security Group
   - Create separate TCP backends for ports: 80, 443, 6443, 9443, 8???
   - Create separate TCP listeners for each port, pointing to the correct backend

NOTES:
* Good luck creating the VMs! I kept getting an error that indicated that Oracle were out of resources. That's the free tier for you! Just keep retrying those operations (I used the `oci` cli in a script and kept on retrying until I got all 4 machines)
* I think the free tier is supposed to allow you to create a Network Load Balancer, but I couldn't do this without adding a credit card, hence I used a standard load balancer

## Next steps (ssh, kubectl)
1. Register DNS A records for _your domain_ matching these:
   - www.example.com - Load balancer (reserved IP)
   - k8sapi.example.com - Load balancer (reserved IP)
   - k8s1.example.com - node1's public IP
   - k8s2.example.com - node2's public IP
   - k8s3.example.com - node3's public IP
   - k8s4.example.com - node4's public IP

3. Add _internal IP addresses_ for all 4 host FQDNs to `/etc/hosts` on _all hosts_
4. Run `k0sctl apply --disable-telemetry`
5. Run `./ingress.sh`
6. Run `./webapp.sh`

Once that's all done, you should have a working website running on www.example.com!

