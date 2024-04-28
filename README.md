# 4 node K3S on Oracle OCI Free Tier
This project allows you to deploy a real working k3s cluster on the Oracle's generous "always free" tier. You get 1 server and 3 dedicated workers. `kubectl top nodes` looks like this:
```
$ kubectl top nodes
NAME                     CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
inst-canri-k3s-workers   40m          4%     1000Mi          16%       
inst-ded0p-k3s-workers   41m          4%     914Mi           15%       
inst-ign06-k3s-workers   35m          3%     1133Mi          19%       
inst-nsvzh-k3s-servers   122m         12%    2232Mi          37%
```

Even if you don't deploy any workloads to the server, this leaves ~15gb of memory and 95%+ of 3x ARM CPUs. Not bad for an always-free cluster!

DISCLAIMERS:

1. The Ampere A1 instance shape used in this project is eligible for the free tier. But I found it extremely difficult to deploy this project, with OCI reporting that these instances are at full capacity in my region. I also found it impossible to deploy an instance pool with more than 2 instances in it (which I wanted for my workers). I decided to upgrade my account (which requires a credit card). And just like that, I could reliably deploy all 4 instances, and the worker instance pool had no problem with 3x instances. So this project basically requires an upgraded OCI account with a credit card on it. (But it still shouldn't cost you anything)

2. This isn't a production grade setup because it deploys a single k3s server. If you lose that node, the cluster is dead. See the availability section at the end of this readme for backup/restore instructions.

# Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0) and upgrade to a paid account)
2. Download and install the following:
   - [terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools)
   - [helm](https://helm.sh/docs/intro/install)
   - [oci-cli](https://github.com/oracle/oci-cli/releases)
   - [kubeseal](https://github.com/bitnami-labs/sealed-secrets) (optional)
   - [flux](https://fluxcd.io/flux/installation/) (optional)
   - [jq](https://jqlang.github.io/jq/download/) (optional)

# Terraform
This project contains two modules:
- network: deploys VCN, security groups and rules, load balancers etc
- cluster: deploys instance pools for k3s server and workers

Once Kubernetes is running, the server bootstrap script deploys:
- Longhorn (CSI, provides persistent volumes using instance local storage)
- Traefic ingress controller (installed automatically, using Helm)
- Metrics Server (installed automatically, using kubectl apply)

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
terraform apply
```

## Copy the kubeconfig from the server
When you terraform apply finishes, terraform will output a bunch of IP addresses (yeah, these are also fake):
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

You should copy the `/etc/rancher/k3s/k3s.yaml` from the server to your machine and update its `server:` address to that of the `nlb_ip_address`. Example:
```
scp ubuntu@151.182.123.14:/etc/rancher/k3s/k3s.yaml /tmp/
sed -i '/server:/ s/127.0.0.1/151.183.24.123/' /tmp/k3s.yaml
```

You will probably want to rename the server, user and context to suit you, but otherwise you can test this right away by running:
```
export KUBECONFIG=/tmp/k3s.yaml
kubectl get nodes
```

If that worked, then you can generate a new `~/.kube/config` file that combines this with your existing kube configs:
```
export KUBECONFIG=/tmp/k3s.yaml:~/.kube/config
kubectl config view --flatten
```

If the output looks good, pipe it to `~/.kube/config`. 

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

# Next Steps: GitOps
This project does not attempt to deploy important things like Cert Manager, External DNS, Sealed Secrets etc. These items are better off being deployed by a GitOps solution like FluxCD or ArgoCD. This is an extremely high-level description of how I proceeded with my FluxCD deployment after creating my cluster...

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

# Availability
## Server Backup / Restore
This cluster has a single server, so losing that means that your cluster is dead. Rebooting the node should be ok, but terminating the node would result in a brand new node that would run through the k3s bootstrap process all over again. You can back up your cluster, so that it can be restored after a k3s server redeploy. The official k3s [documentation](https://docs.k3s.io/datastore/backup-restore) makes it sound like a simple affair (back up the server token and db directory, and restore them afterwards) but it's not. A more detailed [backup/restore process](https://github.com/gilesknap/k3s-minecraft/blob/main/useful/deployed/backup-sqlite/README.md) can be summarize as follows...

### Backing up the server:
* `systemctl stop k3s`
* Back up `/var/lib/rancher/k3s/server` directory
* Back up `/etc/systemd/system/k3s.service`
* Back up `/etc/rancher/k3s/config.yaml`
* `systemctl start k3s`

### Restoring the server:
* `systemctl stop k3s`
* `rm -rf /var/lib/rancher/k3s/server`
* Restore `/var/lib/rancher/k3s/server` directory
* Restore `/etc/systemd/system/k3s.service`
* Restore `/etc/rancher/k3s/config.yaml`
* `systemctl start k3s`

My goal is to add an object store to this terraform project and automate the process of detecting a backup and restoring it during the k3s server bootstrap process. For now though, you could try doing it manually.

## Worker node redundancy
The workers are already redundant and will recover automatically in this setup. I tested this by selecting a random node (in my case, called "inst-canri-k3s-workers"") ran the following:
- `kubectl drain inst-canri-k3s-workers --delete-emptydir-data --ignore-daemonsets`
- `kubectl delete nodes inst-canri-k3s-workers`

I then terminated the OCI instance and waited for a few minutes. A new OCI instance was provisioned and a short while later, it appeared in the k3s cluster. Friggin' yay.

## Data redundancy? Yes!
If you use persistent volumes in your deployments, then Longhorn handles these. Longhorn gives you distributed persistent storage using the raw storage capacity of your servers. Beware that while its performance is OK for reads, it's not good for heavy writes. But hey, this is a totally free cluster. If you want more oomph, install Oracle's CSI and pay for provisioned storage instead.
