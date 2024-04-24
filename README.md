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

# Before you begin
## Pre-requisites
1. Oracle Cloud account (sign up [here](https://signup.cloud.oracle.com0) and upgrade to a paid account)
2. Download and install the following:
   - [terraform](https://www.terraform.io/downloads)
   - [kubectl](https://kubernetes.io/docs/tasks/tools)
   - [helm](https://helm.sh/docs/intro/install)
   - [oci-cli](https://github.com/oracle/oci-cli/releases)

## Network Security
Some facts about OCI:
- Security Lists apply to all VNICs in the VCN. We'll use that to allow ssh (port 22) access from our home IP address
- Network Security Groups only affect resources they're attached to (eg: instances, load balancers)

# Terraform
This project contains two modules:
- network: deploys VCN, security groups and rules, load balancers etc
- cluster: deploys instance pools for k3s server and workers

Once Kubernetes is running, the server bootstrap script deploys:
- Longhorn (CSI, provides persistent volumes using instance local storage)
- Traefic ingress controller (installed automatically, using Helm)
- Metrics Server (installed automatically, using kubectl apply)

## Missing pieces...
To make it easier to deploy real stuff to the cluster, we still need:
- cert-manager
- external-dns
- a domain!

However, I haven't gotten to this yet. Also, you might want to use HTTPS01 or DNS01 ACME challenges for cert manager, and you might have a totally different DNS provider. I might add my Cloudflare setup to this project, with example `values.yaml` files for cert-manager and external-dns helm charts.

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

# Next Steps: GitOps
The most popular options right now are FluxCD and ArgoCD. I'm going with FluxCD because I know it better, and it consumes fewer resources.

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

The `kustomization.yaml` just containes a single Kustomization resource that refers to the two gotk files:
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
```

## Deploy something using GitOps!
At this point you should decide on a directory structure for your FluxCD repo. This example shows a typical monorepo deployment with separate 'staging' and 'production' environments:

```
├── clusters
│   └── mylovelycluster
│       └── flux-system
│           ├── gotk-components.yaml
│           ├── gotk-sync.yaml
│           ├── staging-apps.yaml     <-- contains a kustomization of type: GitRepository, which loads your apps/staging/kustomize.yaml
│           └── kustomization.yaml
└── apps
    ├── base                     <-- contains resources like HelmRelease, Kustomize, etc
    └── staging            
        ├── kustomization.yaml   <-- applies resources from '../base', and patches the from overrides.yaml
        └── overrides.yaml
```

You could also your app configs into another git repo entirely, and refer use this in your `clusters/mylovelycluster/staging/kustomize.yaml`
```
spec:
  interval: 10m0s
  sourceRef:
    kind: GitRepository
    name: some-other-git-repo
    path: ./apps/staging
```

# Availability
## Server Backup / Restore
This cluster has a single server, and if you lose that, it's game over. So it makes sense to back it up, and restore to a new server in the event of a failure. The official k3s [documentation](https://docs.k3s.io/datastore/backup-restore) makes it sound like a simple affair (back up the server token and db directory, and restore them afterwards) but it's not. A more detailed [backup/restore process](https://github.com/gilesknap/k3s-minecraft/blob/main/useful/deployed/backup-sqlite/README.md) can be summarize as follows...

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

That could probably be scripted, but we would have to modify the server template to detect a remote k3s server backup and restore it as part of the k3s installation process. 

## Worker node redundancy
The workers are already redundant and will recover automatically in this setup. I tested this by selecting a random node (in my case, called "inst-canri-k3s-workers"") ran the following:
- `kubectl drain inst-canri-k3s-workers --delete-emptydir-data --ignore-daemonsets`
- `kubectl delete nodes inst-canri-k3s-workers`

I then terminated the OCI instance and waited for a few minutes. A new OCI instance was provisioned and a short while later, it appeared in the k3s cluster. Friggin' yay.

## Data redundancy? Yes!
If you use persistent volumes in your deployments, then Longhorn handles these. Longhorn gives you distributed persistent storage using the raw storage capacity of your servers. Beware that while its performance is OK for reads, it's not good for heavy writes. But hey, this is a totally free cluster. If you want more oomph, install Oracle's CSI and pay for provisioned storage instead.
