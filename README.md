# Wireguard server and 2 node K3S Cluster on Oracle OCI Free Tier
This project allows you to deploy a Wireguard server and a k3s cluster on the Oracle's generous "always free" tier. You get:
- 1 Wireguard server
  - 1x AMD VCPU
  - 1GB RAM
  - 50GB block storage (it's the minimum, unfortunately)
- Two k3s nodes
  - 2x ARM Ampere CPUs
  - 12GB RAM
  - 50GB block storage
- External Control Plane Storage
  - Oracle MySQL Heatwave managed DB

The cluster runs:
- Kubernetes 1.35
- CoreDNS
- Traefik
- Metrics Server
- Longhorn

Typical node resources, at install time (`kubectl top nodes`):
```
NAME                     CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
inst-xjoiq-k3s-servers   96m          4%       1581Mi          13%         
inst-zqse8-k3s-servers   64m          3%       1130Mi          9%  
```

Not bad for a completely free cluster!

DISCLAIMERS:

1. The Ampere A1 instance shape used in this project is eligible for the free tier. But I found it extremely difficult to deploy this project, with OCI reporting that these instances are at full capacity in my region. I also found it impossible to deploy an instance pool with more than 2 instances in it (which I wanted for my workers). I decided to upgrade my account (which requires a credit card). And just like that, I could reliably deploy all 4 instances, and the worker instance pool had no problem with 3x instances. So this project basically requires an upgraded OCI account with a credit card on it. (But it still shouldn't cost you anything)

2. This isn't a production grade setup because it deploys a single k3s server. If you lose that node, the cluster is dead. See the availability section at the end of this readme for backup/restore instructions.

# Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0) and upgrade to a paid account)
2. Download and install the following:
   - [terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools)
   - [jq](https://jqlang.github.io/jq/download/)
   - [oci-cli](https://github.com/oracle/oci-cli/releases)
3. Install optional components
   - [helm](https://helm.sh/docs/intro/install)
   - [kubeseal](https://github.com/bitnami-labs/sealed-secrets) (optional)
   - [flux](https://fluxcd.io/flux/installation/) (optional)
   - Wireguard

# Terraform
This project contains three modules:
- network: deploys VCN, security groups and rules, load balancers etc
- wireguard: deploys an instance pool for Wireguard
- mysql: deploys Oracle Heatwave database for the control plane
- cluster: deploys an instance pool for the k3s nodes

Once Kubernetes is running, the server bootstrap script deploys Longhorn by default, so you can create PVs using the additional storage space on the nodes.

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

# Cluster config
cluster_name = "mycluster"
arm_image_id = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaak2aoytfgjiozi4tkuwumcn6ayupwlp5ubvnyturcktirkwx63kea"
mysql_admin_password = "B1gS3cr3tp4ssw0rd!"
customer_contacts = [
  "me@gmail.com"
]

# VPN config
x86_image_id = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaado6ekhtx7ownjkyel6vbdzmp47ur24r7gjxef4cbgwx5fbdg2lsa"
wg_clients   = [
  "mylaptop"
]
```
 
## Apply terraform
There's more to it than this, but basically...
```
terraform init
terraform plan
terraform apply
```

Just be aware: the MySQL Heatwave database can take at least 10 minutes to create. When terraform has finished, the output should look something like this:

```
ingress_nlb_ip_address = "132.92.151.10"
private_lb_ip_address = "10.0.1.6"
servers_ips = [
  "132.93.136.18",
  "195.124.51.250",
]
wireguard_public_ip = "132.94.14.1"
wg_client_bucket = {
  namespace = "alfgsdijercow4"
  bucket    = "wireguard-client-configs"
}
```

# Accessing the k3s cluster 

## SSH to either of the servers
This Terraform project allows SSH from the public IP address you used when you ran terraform apply. This means that you can ssh to either of the `server_ips`. 

```
ssh ubuntu@132.93.136.18
```

## Configure your .ssh/config for easier access
To make it easy to ssh to the nodes, or create a port-forward tunnel, run `./ssh_config.sh` to generated ssh config entries for all servers deployed. If the output looks OK to you, direct the output of the script to your `~/.ssh/config` file. 

## Set up your kubeconfig
Next, grab the k3s.yaml file from either of the servers. It's at the path `/etc/rancher/k3s/k3s.yaml`. These commands will grab it, rename the cluster to 'oci-k3s' and add it to your existing KUBECONFIG. It just writes it out to the terminal, so catch it in a file, double check it and copy it to ~/.kube/config if you are happy with it

```
ssh k3s1 sudo cat /etc/rancher/k3s/k3s.yaml \
| sed 's/: default/: oci-k3s/g' \
 > /tmp/k3s.yaml
```

Inspect it. If you're happy, this command will merge it with your existing KUBECONFIG and save to ~/.kube/config

```
export KUBECONFIG=/tmp/k3s.yaml:~/.kube/config
kubectl config view --flatten > ~/.kube/config
unset KUBECONFIG
```

## Create a tunnel and run kubectl
At this point you should be able to tunnel to either of the nodes and run kubectl:

```
# Create tunnel
ssh -fN k3s-tunnel1

# Select the right kubectl context
kubectl config use-context oci-k3s

# OK, now let's see if it works!
kubectl get nodes
kubectl get pods -A
kubectl top nodes

# When you're done, stop the tunnel
ssh -O stop k3s-tunnel1
ssh -O exit k3s-tunnel1
```

# Wireguard VPN

This project deploys a Wireguard VPN server on an AMD `VM.Standard.E2.1.Micro` instance (part of the Always Free tier). It gives you a secure tunnel into the private subnet, letting you reach the k3s nodes and MySQL instance without exposing them further to the internet.

## What gets created

- A Wireguard instance in the private subnet with a public IP
- A dedicated NSG allowing inbound UDP on the Wireguard port and SSH from your home IP
- An Object Storage bucket (`wireguard-client-configs`) where client configs are automatically
  uploaded after the instance boots
- IAM policy allowing the instance to write to that bucket using instance principal auth
  (no credentials stored on the box)

## Configuring clients

Set the list of client names in your `env.auto.tfvars`:

```hcl
wg_clients     = ["zenbook", "phone"]
wireguard_port = "51820"   # default, override if needed
```

After `terraform apply`, the instance will boot, generate a unique keypair for each client,
and upload the configs to Object Storage. Retrieve a config with:

```bash
# Get the bucket details from terraform output
terraform output wg_client_bucket

# Download a client config (replace namespace/name with values from the output above)
oci os object get \
  --namespace <namespace> \
  --bucket-name wireguard-client-configs \
  --name zenbook.conf \
  --file ~/zenbook.conf

# Connect
wg-quick up ~/zenbook.conf
```

## Re-deployment behaviour

If the Wireguard instance is terminated (manually or by OCI), the instance pool will spawn a replacement. The new instance will generate a **fresh set of keys** and overwrite the existing configs in the bucket. This means:

- Old client configs will stop working immediately
- Download the new configs from the bucket and reconnect

This is intentional — there is no point keeping old client configs that were encrypted with a server key that no longer exists.

## x86 image ID

The Wireguard instance uses an AMD x86 image, separate from the ARM image used for k3s nodes. Add the Ubuntu 24.04 x86 image OCID for your region to `env.auto.tfvars`:

```hcl
x86_image_id = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaaXXXXXXXXXXXXXXXXXX"
```

Find the correct OCID in the [OCI console](https://docs.oracle.com/en-us/iaas/images/) under **Compute > Images > Platform Images**, filtering for Ubuntu 24.04 and your region.

# Network Security
## Security List
Security Lists apply to all VNICs in the VCN. We'll use that to allow ssh (port 22) access from our home IP address to all k3s nodes.

## Public Network Load Balancer & Security Group
This deploys a public NLB to allow ingress into the cluster, and allow access to the kubeapi from your home IP. Only the k3s server is added to the backend set. The listeners / rules are:
- http (port 80), accessible from anywhere
- https (port 443), accessible from anywhere
- kubeapi (port 6443), accessible only from your home IP address

## Private Load Balancer & Security Group
We also deploy a private LB that the k3s workers use to reach the kubeapi internally. It also contains backends for ports 80 and 443. All nodes are added to this backend set. The security group only allows traffic from the public load balancer.

# Next Steps: GitOps, External DNS, Sealed Secrets etc. 
These items are better off being deployed by a GitOps solution like FluxCD or ArgoCD. This is an extremely high-level description of how I proceeded with my FluxCD deployment after creating my cluster...

## Create a Git repo and a temporary fine-grained authorization token
I'm using github, so if you're using some other source control, modify these instructions.

* Create a Github repo for flux (I used `fluxcd-example`)
* Create a Github fine-grained personal access token
  * Only grant it access to the `fluxcd-example` repo
  * Grant the following permissions, under Repository:
    * Metadata
    * Administration > read & write
    * Content > read & write

## Install FluxCD
```
$ curl -s https://fluxcd.io/install.sh | sudo bash
$ flux completion bash | sudo tee /etc/bash_completion.d/flux
```

## Bootstrap FluxCD in your cluster
First, make sure your KUBECONFIG is pointing to the right cluster:
```
$ kubectl cluster-info
```

Then set the environment variable GITHUB_TOKEN to your fine-grained access token:
```
$ export GITHUB_TOKEN=github_pat_123456ABCDEF_0987654321POIUYTRREWETCETCETC`
```

Now, we can check that we have everything we need, and finally bootstrap the cluster:
```
$ flux check --pre
$ flux bootstrap \
    github \
    --owner=raffraffraff \
    --repository=fluxcd-example \
    --branch=main \
    --path clusters/mylovelycluster \
```

The output should look like this:
```
► cloning branch "main" from Git repository "https://github.com/raffraffraff/fluxcd-example.git"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed sync manifests to "main" ("188455d0c3f0882ff0bd24adcb61733294933ff6")
► pushing component manifests to "https://github.com/raffraffraff/fluxcd-example.git"
► installing components in "flux-system" namespace
✔ installed components
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
✔ public key: ecdsa-sha2-nistp384 ABCDEFGHIJKLIMNO1234567890
✔ configured deploy key "flux-system-main-flux-system" for "https://github.com/raffraffraff/fluxcd-example"
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("ca709547287d31c4d72c71a9fdf82667d64bfb4e")
► pushing sync manifests to "https://github.com/raffraffraff/fluxcd-example.git"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy
```

NOTE: FluxCD generates a read-only deploy key in your git project, and uses that from this point on, so you can delete the fine-grained personal access token if you wish.

During the bootstrap process, FluxCD pushes the cluster config back to the 'fluxcd-example' Github repo:
```
clusters
└── mylovelycluster
   └── flux-system
       ├── gotk-components.yaml
       ├── gotk-sync.yaml
       └── kustomization.yaml
```

You don't touch these. The `kustomization.yaml` just containes a single Kustomization resource that refers to the two gotk files:
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
```

## Deploy something useful, with GitOps!
The most obvious next steps for me were to deploy:
- Bitnami sealed-secrets, which provide a safe way to check encrypted secrets into my git repo (NOTE: enable sealed secrets ingress!)
- Cert Manager, which automatically fetches certs from LetsEncrypt when I deploy a new ingress
- External DNS, which automatically registers a new hostname on my domain when I deploy a new ingress

```
├── clusters
│   └── mylovelycluster
│       ├── flux-system                 <-- don't touch any of the files in here!
│       │   ├── gotk-components.yaml
│       │   ├── gotk-sync.yaml    
│       │   └── kustomization.yaml
│       └── infrastructure.yaml         <-- I added this to deploy my infrastructure stuff
└── infrastructure
    ├── configs
    │   ├── cert-issuers.yaml
    │   ├── external-dns.yaml
    │   └── kustomization.yaml          <-- deploys cert-issuers.yaml, which configures cert-manager
    └── controllers
        ├── cert-manager.yaml
        ├── external-dns.yaml
        ├── sealed-secrets.yaml
        └── kustomization.yaml          <-- deploys cert-manager.yaml and sealed-secrets.yaml
```

# Cluster Availability
This cluster has two servers. It outsources control plane persistence to a managed MySQL service called Oracle Heatwave. You should be able to reboot either node without losing cluster state. Terminating either node results in the instance pool spawning a replacement, which will go throught the k3s bootstrap process. 

## Data redundancy? Yes!
If you use persistent volumes in your deployments, then Longhorn handles these. Longhorn gives you distributed persistent storage using the raw storage capacity of your servers. Beware that while its performance is OK for reads, it's not good for heavy writes. But hey, this is a totally free cluster. If you want more oomph, install Oracle's CSI and pay for provisioned storage instead.

You could also install the Oracle OCI storage manager, and have it auto-provision block storage volumes in response to PVCs)