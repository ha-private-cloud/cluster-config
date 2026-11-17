# cluster-config

The shared services inside the Talos cluster that every ClusterKeep app relies on, installed with OpenTofu. The cluster itself comes from `proxmox-tofu`.

## What it installs

- **ingress-nginx** as a DaemonSet on the host network of each worker, so it listens on ports 80 and 443 directly. There's no load balancer on bare metal.
- **csi-driver-nfs** with one StorageClass, `nfs-csi`, which is the default. It points at 192.168.0.148, the address of the highly available NFS pair from `proxmox-tofu`, so volumes follow whichever NFS VM is serving. The volumes use the `Retain` reclaim policy.
- **Headlamp**, the Kubernetes dashboard, at headlamp.clusterkeep.dev.net. It signs in through auth-api, with its client settings read from `cluster-auth`'s state.
- **Nexus** as the container registry. The web interface is at nexus.clusterkeep.dev.net and Docker images go to registry.clusterkeep.dev.net. Its Java memory is sized to fit inside the pod's limit.
- A **CoreDNS** change so pods can reach Headlamp and the registry by their local names through ingress-nginx.
- The **Cloudflare Tunnel** that makes production public. Only the routes in `cloudflare_tunnel_ingress` are reachable from the internet, and only namespaces ending in `-pub` can be listed:

  | Hostname | Goes to |
  |---|---|
  | clusterkeep.com | clusterkeep-ui |
  | dashboard.clusterkeep.com | storage-ui |
  | auth.clusterkeep.com | auth-api |
  | admin.clusterkeep.com | admin-ui |

- The **namespaces** each app deploys into, because namespaces are shared across the cluster. Each app's own OpenTofu only looks its namespace up.

  | App | Namespaces |
  |---|---|
  | clusterkeep-ui | `clusterkeep-dev-pub`, `clusterkeep-prv-pub`, `clusterkeep-prd-pub` |
  | storage-ui | `storage-dev-pub`, `storage-prv-pub`, `storage-prd-pub` |
  | admin-ui | `admin-ui-dev-pub`, `admin-ui-prv-pub`, `admin-ui-prd-pub` |
  | auth-api | `auth-dev-pub`, `auth-prv-pub`, `auth-prd-pub` |
  | storage-api | `storage-dev-priv`, `storage-prv-priv`, `storage-prd-priv` |

- An `infra` namespace holding each NFS VM's console login as a Secret.

## Using it

All the OpenTofu files are in `tofu/`. The tfvars on the CI bastion hold the kubeconfig path and the Cloudflare details.

Pushing a `vX.Y.Z` tag plans the change through the shared `pipelines` workflow. Applying it is always a manual run of that workflow with the tag. To run it by hand from the bastion:

```sh
cluster-cli tofu cluster-config plan
cluster-cli tofu cluster-config apply
```

Changing a namespace here deletes the old one and everything in it, so redeploy the apps that used it straight after.

## Reaching the internal sites

Every `*.clusterkeep.dev.net` name is resolved by the dnsmasq server on the CI bastion. From another machine on the network, use the bastion as its DNS server.

Headlamp signs in through auth-api. Anyone in the `cluster-admins`, `cluster-editors` or `cluster-viewers` group gets that level of access, and a cluster admin can change someone's group in admin-ui.

## Setting up Nexus

The Helm chart only starts Nexus. These are one-time steps:

1. Get the generated admin password and log in to nexus.clusterkeep.dev.net as `admin`:

   ```sh
   kubectl exec -n nexus deploy/nexus-nexus-repository-manager -- cat /nexus-data/admin.password
   ```

2. Create a **docker (hosted)** repository called `docker-hosted` with HTTP on port 5000, and turn on the **Docker Bearer Token Realm** under Security, Realms.
3. Apply `cluster-network/static-ips/patches/_registry2.yaml` to every node so they can resolve and pull from the registry.

Apps pull images without logging in. cluster-ci has its own push user.

## Known issue

The NFS StorageClasses name each volume's folder after its namespace and claim. A deleted claim's data stays on the NFS server, and a new claim with the same name in the same namespace picks it back up. Clear out the old folder before recreating a claim.
