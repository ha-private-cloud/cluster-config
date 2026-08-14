# Runs cloudflared in-cluster to expose clusterkeep-ui at
# login.clusterkeep.com via a Cloudflare Tunnel , no port forwarding, no
# public IP needed. Tunnel itself (ID + credentials.json) is created
# out-of-band via `cloudflared tunnel create` (see README); this just runs
# the connector and wires its ingress rule to clusterkeep-ui's Service.
# Reuses the "infra" namespace from nfs-storage-secret.tf.
#
# Headlamp is deliberately NOT routed through this tunnel , LAN-only
# access via headlamp.talos.lab, see cluster_config_addons.md.

resource "kubernetes_secret" "cloudflare_tunnel_credentials" {
  metadata {
    name      = "cloudflare-tunnel-credentials"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  data = {
    "credentials.json" = file(var.cloudflare_tunnel_credentials_path)
  }
}

resource "helm_release" "cloudflare_tunnel" {
  name       = "cloudflare-tunnel"
  repository = "https://cloudflare.github.io/helm-charts"
  chart      = "cloudflare-tunnel"
  version    = var.cloudflare_tunnel_chart_version
  namespace  = kubernetes_namespace.infra.metadata[0].name

  values = [
    templatefile("${path.module}/../values/cloudflare-tunnel.yaml.tftpl", {
      account_id  = var.cloudflare_account_id
      tunnel_name = var.cloudflare_tunnel_name
      tunnel_id   = var.cloudflare_tunnel_id
      secret_name = kubernetes_secret.cloudflare_tunnel_credentials.metadata[0].name
      hostname    = var.cloudflare_tunnel_hostname
    })
  ]
}
