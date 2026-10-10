resource "kubernetes_namespace" "auth_api" {
  for_each = var.auth_api_namespaces

  metadata {
    name = each.value
  }
}

resource "kubernetes_secret" "auth_api_registry" {
  for_each = var.clusterkeep_ui_registry_username != "" ? var.auth_api_namespaces : {}

  metadata {
    name      = "auth-api-registry"
    namespace = kubernetes_namespace.auth_api[each.key].metadata[0].name
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
