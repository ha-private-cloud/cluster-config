resource "kubernetes_namespace" "admin_ui" {
  for_each = var.admin_ui_namespaces

  metadata {
    name = each.value
  }
}

resource "kubernetes_secret" "admin_ui_registry" {
  for_each = var.clusterkeep_ui_registry_username != "" ? var.admin_ui_namespaces : {}

  metadata {
    name      = "admin-ui-registry"
    namespace = kubernetes_namespace.admin_ui[each.key].metadata[0].name
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
