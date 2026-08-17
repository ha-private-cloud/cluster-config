# OIDC app (Authentik) is managed in cluster-auth; read its outputs instead of duplicating.
data "terraform_remote_state" "cluster_auth" {
  backend = "local"

  config = {
    path = "${path.module}/../../cluster-auth/tofu/terraform.tfstate"
  }
}

resource "kubernetes_namespace" "headlamp" {
  metadata {
    name = var.headlamp_namespace
  }
}

# Chart already provisions a cluster-admin "headlamp" ServiceAccount by default; reused as the login identity.
resource "helm_release" "headlamp" {
  name       = "headlamp"
  repository = "https://kubernetes-sigs.github.io/headlamp/"
  chart      = "headlamp"
  version    = var.headlamp_chart_version
  namespace  = kubernetes_namespace.headlamp.metadata[0].name

  values = [
    templatefile("${path.module}/../values/headlamp.yaml.tftpl", {
      hostname                = var.headlamp_hostname
      ingress_tls_secret_name = var.ingress_tls_secret_name
      oidc_client_id          = data.terraform_remote_state.cluster_auth.outputs.headlamp_oidc_client_id
      oidc_issuer_url         = data.terraform_remote_state.cluster_auth.outputs.headlamp_oidc_issuer_url
    })
  ]

  # Kept out of `values` , helm_release.values is not a sensitive attribute and
  # renders in full in plan output.
  set_sensitive {
    name  = "config.oidc.clientSecret"
    value = data.terraform_remote_state.cluster_auth.outputs.headlamp_oidc_client_secret
  }
}
