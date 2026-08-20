resource "random_bytes" "cloudflare_tunnel_secret" {
  length = 32
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "clusterkeep" {
  account_id    = var.cloudflare_account_id
  name          = var.cloudflare_tunnel_name
  tunnel_secret = random_bytes.cloudflare_tunnel_secret.base64
  config_src    = "cloudflare"

  lifecycle {
    prevent_destroy = true
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "clusterkeep" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.clusterkeep.id

  config = {
    ingress = concat(
      [for r in var.cloudflare_tunnel_ingress : {
        hostname = r.hostname
        service  = "http://${r.service}.${r.namespace}.svc.cluster.local:${r.port}"
      }],
      [{ service = "http_status:404" }]
    )
  }
}

resource "cloudflare_dns_record" "tunnel" {
  for_each = { for r in var.cloudflare_tunnel_ingress : r.hostname => r }

  zone_id = var.cloudflare_zone_id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.clusterkeep.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1

  lifecycle {
    prevent_destroy = true
  }
}

resource "kubernetes_secret" "cloudflare_tunnel_credentials" {
  metadata {
    name      = "cloudflare-tunnel-credentials"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  data = {
    "credentials.json" = jsonencode({
      AccountTag   = var.cloudflare_account_id
      TunnelID     = cloudflare_zero_trust_tunnel_cloudflared.clusterkeep.id
      TunnelSecret = random_bytes.cloudflare_tunnel_secret.base64
    })
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
      tunnel_name = cloudflare_zero_trust_tunnel_cloudflared.clusterkeep.name
      tunnel_id   = cloudflare_zero_trust_tunnel_cloudflared.clusterkeep.id
      secret_name = kubernetes_secret.cloudflare_tunnel_credentials.metadata[0].name
    })
  ]

  depends_on = [cloudflare_zero_trust_tunnel_cloudflared_config.clusterkeep]
}
