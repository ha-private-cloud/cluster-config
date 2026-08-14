resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.ingress_nginx_namespace
    # Controller needs hostNetwork/hostPort, blocked by Talos's default PSA baseline level.
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = var.ingress_nginx_chart_version
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name

  values = [file("${path.module}/../values/ingress-nginx.yaml")]
}
