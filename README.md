# Quick start
## Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0)
2. Register a domain (you can use an existing domain either)
3. Download and install the following:
   - terraform
   - kubectl
   - helm
   - k0sctl
   - jq

# Oracle Free Tier
This is a very opinionated setup that takes advantage of Oracle's extremely generous "always free" tier. We will be using:
- 1 VCN (a virtual network, like AWS VPC)
- 1 standard Load Balancer (I couldn't launch a Network LB on the free tier)
- 4x VMs that each have 1 Ampere (ARM) CPU, 6GB memory and 50GB disk

That's about it. There are other freebies too (databases, object storage etc) but I have not yet used them. _For now_ I don't have terraform code to spin up the infrastructure, but that's the next thing on my TODO list. When I do that, I'll be making use of the object store, and adding some notes about configuring the OCI command line utility `oci`

## Quick notes on Load Balancers
You can only add a single Load Balancer on the free tier, but it supports:
- Multiple backend groups, each with its own protocol/port/health config
- Multiple listeners, each with its own protocol/port/backend config

## Quick notes on Network Security
- Security Lists apply to all VNICs in the VCN
- Network Security Groups apply to selected VNICs (...apparently - I can't select which ones my group uses!)
- The Load Balancer can use Network Security Group

# k0s
k0s is a Kubernetes distribution that can be launched using a single binary. However, it also supports highly-available clusters, and is fully CNCF compliant.

## Quick notes on k0s
### eBPF / Cilium / latest shit?
I really wanted to do this from the start, because I like the sound of eBPF replacing iptables and kube-proxy. Unfortunately, it's flakey AF right now - I couldn't get Cilium pods to stay up. I don't want to knock Cilium, because this was definitely some weird networking quirk of my setup. I'll come back to this!

### Turning off metrics-server and konnectivity-server
By default, k0s is a minimally opinionated Kubernetes distro that comes with metrics-server, konnectivity, coredns. However, in my particular setup (no "automatic" Cloud Load Balancer, highly-available control plane with no taints) nothing worked properly until I...
1. Disabled konnectivity-server (it's not needed in this setup)
2. Disabled metrics-server (didn't work, and timed out requests causing every kubectl action to take forever)

# Ingress Notes
Ingress allows you to accept traffic into the cluster and direct it to different services based on rules. Ingress itself relies on _some other networking setup_ to let the traffic in. On AWS EKS, it's probably a Load Balancer. But on _this_ cluster, unless you want to install a load balancer controller in your cluster and pay for an additional Load Balancer, you need to do things differently:
- Ingress will run with hostNetwork=true
- The port of the nginx pod will be exposed directly on the node it runs on
- Your Oracle load balancer port 80 listener will sent traffic to a backend group that uses _the port you expose nginx ingress on_

# Steps...
OK, since I don't have this stuff terraformed yet, I'm going to list the steps you need to carry out manually. (Sorry)

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
6. Allow all traffic from your home IP address (you can open this up to the world if you want but I don't adivse it)
7. Create a standard load balancer:
   - Attach Network Security Group
   - Create separate TCP backends for ports: 80, 443, 6443, 9443, 8???
   - Create separate TCP listeners for each port, pointing to the correct backend
8. Create DNS entries for _public IPs_
   - www.example.com - Load balancer
   - k8sapi.example.com - Load balancer
   - k8s1.example.com - node1 public IP
   - k8s2.example.com - node2 public IP
   - k8s3.example.com - node3 public IP
   - k8s4.example.com - node4 public IP
9. Add _internal IP addresses_ for all 4 hosts to `/etc/hosts` on _all hosts_
10. `k0sctl apply --disable-telemetry`
11. `./ingress.sh`
12. `./webapp.sh`

Once that's all done, you should have a working website running on www.example.com!

