# cluster-config

Kubernetes config for the Talos cluster provisioned in
[`../proxmox-tofu`](../proxmox-tofu). Installs via OpenTofu:

- **ingress-nginx** — ingress controller, runs as a `hostNetwork` DaemonSet
  on the two worker nodes (no LoadBalancer on bare metal, so it binds
  80/443 directly on the hosts).
- **Headlamp** — Kubernetes web UI, exposed through ingress-nginx.
- **csi-driver-nfs** — default StorageClass (`nfs-csi`) backed by the NFS
  VM from `../proxmox-tofu`. Reclaim policy `Retain`.
- An `infra` namespace with an `nfs-storage-credentials` Secret, mirroring
  the NFS VM's console login from `proxmox-tofu`'s state so it's reachable
  via `kubectl` instead of `tofu output` in another repo.
- **Nexus Repository Manager** (`nexus.tf`) — the cluster's container
  registry. App repos push images here; their own Tofu then deploys
  pointing at whatever tag it just pushed. Exposed through ingress-nginx:
  web UI at `nexus_hostname`, docker connector at `nexus_docker_hostname`.
  The actual "docker (hosted)" repository is a one-time manual step (see
  below).
- A CoreDNS patch (`coredns.tf`) adding `hosts` entries for
  `auth.talos.lab`/`headlamp.talos.lab` → ingress-nginx's ClusterIP, so
  Headlamp's in-pod OIDC calls to Authentik can resolve `*.talos.lab`
  (cluster DNS otherwise only knows what's in workstations' `/etc/hosts`).
- Headlamp's `config.oidc` values, read from `../cluster-auth`'s Tofu
  state. Also sets `HEADLAMP_CONFIG_OIDC_SKIP_TLS_VERIFY=true`, since
  Authentik sits behind ingress-nginx's self-signed cert.

## Prerequisites

- `tofu` (OpenTofu)
- A working kubeconfig from the cluster bootstrap

## Usage

Create `terraform.tfvars`:
```
kubeconfig_path   = ""
headlamp_hostname = "headlamp.talos.lab"
```

Run tofu:
```sh
tofu init
tofu plan
tofu apply
```

## Accessing Headlamp

1. Point both hostnames at a worker node IP (ingress-nginx only runs on
   workers). Add to your browser machine's `/etc/hosts` — separate from
   the CoreDNS patch above, which only covers in-cluster resolution:

   ```
   192.168.0.16  headlamp.talos.lab
   192.168.0.16  auth.talos.lab
   ```

   (`auth.talos.lab` is needed too — the SSO button redirects your browser
   there directly.)

2. Browse to `https://headlamp.talos.lab`

3. Either:
   - Click **Sign in with SSO** and log in with an Authentik account (see
     `../cluster-auth`'s README for bootstrap admin credentials), or
   - Log in with a token:

     ```sh
     export KUBECONFIG=kubeconfig
     kubectl create token headlamp -n headlamp
     ```

     Paste the token into Headlamp's login screen. It's the chart's
     default ServiceAccount, bound to `cluster-admin`, and expires after
     1 hour (re-run the command for a new one).

## Setting up Nexus as the container registry

The Helm chart only stands Nexus up — the docker-hosted repository and
node-level trust for its self-signed cert are one-time manual steps.

1. Add both hostnames to your workstation's `/etc/hosts` (same worker
   node IP as Headlamp):

   ```
   192.168.0.16  nexus.talos.lab
   192.168.0.16  registry.talos.lab
   ```

2. Get the generated admin password and log in at `https://nexus.talos.lab`
   as `admin`:

   ```sh
   kubectl exec -n nexus deploy/nexus -- cat /nexus-data/admin.password
   ```

3. In **Settings → Repositories → Create repository → docker (hosted)**:
   - Name: `docker-hosted`
   - HTTP: enable, port `5000` (must match `nexus_docker_port`)
   - Enable **Docker Bearer Token Realm** (**Settings → Security →
     Realms**) — required for `docker login`/`push` auth.

4. Every Talos node needs to trust `registry.talos.lab`'s self-signed cert
   and resolve the hostname — neither is true by default. Apply
   [`../proxmox-tofu/talos-registry-patch.yaml`](../proxmox-tofu/talos-registry-patch.yaml)
   (same pattern as `talos-oidc-patch.yaml`, but to *every* node, since
   each pulls images independently):

   ```sh
   cd ../proxmox-tofu
   talosctl patch mc --patch-file talos-registry-patch.yaml \
     --nodes <node-ip> \
     --talosconfig _out/talosconfig
   ```

   Repeat per node (`talosctl get members --talosconfig _out/talosconfig`
   lists them). This changes live cluster nodes — review the patch file
   first.

5. Build/tag/push to `registry.talos.lab` (no port — this goes through
   ingress-nginx on the standard HTTPS port)
   through the same self-signed cert. Docker/Podman need to either trust
   it or be told the registry is insecure
