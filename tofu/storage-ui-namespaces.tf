# Namespaces for storage-ui's dev/prd/prv environments, created here instead of in that app's own Tofu.
resource "kubernetes_namespace" "storage_ui" {
  for_each = var.storage_ui_namespaces

  metadata {
    name = each.value
  }
}

resource "kubernetes_secret" "storage_ui_registry" {
  for_each = var.clusterkeep_ui_registry_username != "" ? var.storage_ui_namespaces : {}

  metadata {
    name      = "storage-ui-registry"
    namespace = kubernetes_namespace.storage_ui[each.key].metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.nexus_docker_hostname) = {
          username = var.clusterkeep_ui_registry_username
          password = var.clusterkeep_ui_registry_password
          auth     = base64encode("${var.clusterkeep_ui_registry_username}:${var.clusterkeep_ui_registry_password}")
        }
      }
    })
  }
}
