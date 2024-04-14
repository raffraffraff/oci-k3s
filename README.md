# Oracle OCI Free Tier
This whole setup is opinionated, but it gets the best out of Oracle's generous "always free" tier:
- 1 VCN (a virtual network, like AWS VPC)
- 1 standard Load Balancer (internal access to kubeapi)
- 1 Network Load Balancer (public access for http/https/kubeapi)
- 4 VMs with 1 Ampere (ARM) CPU, 6GB memory and 50GB disk

DISCLAIMERS:

1. The Ampere A1 instance shape used in this project is eligible for the free tier. But I found it extremely difficult to deploy this project, with OCI reporting that these instances are at full capacity in my region. I also found it impossible to deploy an instance pool with more than 2 instances in it (which I wanted for my workers). I decided to upgrade my account (which requires a credit card). And just like that, I could reliably deploy all 4 instances, and the worker instance pool had no problem with 3x instances. So this project basically requires an upgraded OCI account with a credit card on it. (But it still shouldn't cost you anything)

2. This is a brittle setup, because it deploys a single k3s server and 3x workers. I took this approach because I'm not going to run anything critical on it. I may tinker with it later, and perhaps try 3x servers and 1x dedicated worker, and allow workloads to run on the servers. If you use this project and decide to try that out, send me a pull request if it works!

# Before you begin
## Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0) and upgrade to a paid account)
2. Download and install the following:
   - [terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools)
   - [helm](https://helm.sh/docs/intro/install)
   - [jq](https://stedolan.github.io/jq/download)
   - [oci-cli](https://github.com/oracle/oci-cli/releases)

## Network Security
Some facts about OCI:
- Security Lists apply to all VNICs in the VCN. We'll use that to allow ssh (port 22) access from our home IP address
- Network Security Groups only affect resources they're attached to (eg: instances, load balancers)

# Terraform
This project contains two modules:
- network: deploys VCN, security groups and rules, load balancers etc
- cluster: deploys instance pools for k3s server and workers

## Cluster setup
Taking the best possible advantage of OCI's free tier, this project deploys:
- 1x server
- 3x workers

Once Kubernetes is running, it also deploys into it:
- Longhorn (CSI)
- Traefic ingress controller (installed automatically, using Helm)
- Metrics Server (installed automatically, using kubectl apply)

## Missing pieces...
To make it easier to deploy real stuff to the cluster, we still need:
- cert-manager
- external-dns

However, I haven't gotten to this yet. Also, you might want to use HTTPS01 or DNS01 ACME challenges for cert manager, and you might have a totally different DNS provider.

# Deploying it!
## Create an `env.auto.tfvars` file
This file should be placed in the root of the project. Its contents will specific to your OCI account. Here's what I've got in mine (with totally fake details, of course):
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
terraform app
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
sed -i '/server:/ s/127.0.0.1/123.123.123.123/' /tmp/k3s.yaml
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

# So what do you get in the end?
A K3s cluster which you can access from your home IP address. Here's the output of `kubectl top nodes`:
```
$ kubectl top nodes
NAME                     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
inst-canri-k3s-workers   40m          4%     1000Mi          16%       
inst-ded0p-k3s-workers   41m          4%     914Mi           15%       
inst-ign06-k3s-workers   35m          3%     1133Mi          19%       
inst-nsvzh-k3s-servers   122m         12%    2232Mi          37%
```

This leaves around ~15gb of memory and most of the 3x ARM CPUs for you to play with. No bad for free! 
