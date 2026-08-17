resource "kubernetes_namespace" "nexus" {
  metadata {
    name = var.nexus_namespace
  }
}

resource "helm_release" "nexus" {
  name       = "nexus"
  repository = "https://sonatype.github.io/helm3-charts/"
  chart      = "nexus-repository-manager"
  version    = var.nexus_chart_version
  namespace  = kubernetes_namespace.nexus.metadata[0].name

  values = [
    templatefile("${path.module}/../values/nexus.yaml.tftpl", {
      hostname                = var.nexus_hostname
      docker_hostname         = var.nexus_docker_hostname
      docker_port             = var.nexus_docker_port
      storage_size            = var.nexus_storage_size
      ingress_tls_secret_name = var.ingress_tls_secret_name
    })
  ]
}
