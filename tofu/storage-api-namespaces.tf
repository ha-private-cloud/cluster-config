resource "kubernetes_namespace" "storage_api" {
  for_each = var.storage_api_namespaces

  metadata {
    name = each.value
  }
}

resource "kubernetes_secret" "storage_api_registry" {
  for_each = var.clusterkeep_ui_registry_username != "" ? var.storage_api_namespaces : {}

  metadata {
    name      = "storage-api-registry"
    namespace = kubernetes_namespace.storage_api[each.key].metadata[0].name
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
