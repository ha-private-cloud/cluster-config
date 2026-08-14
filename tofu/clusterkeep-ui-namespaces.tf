# Namespaces for clusterkeep-ui's dev/prd/prv environments, created here
# instead of in that app's own Tofu , a namespace is a cluster-wide
# primitive, not something an app repo should own the lifecycle of.
# clusterkeep-ui's Tofu only looks these up (see its clusterkeep-ui.tf), it
# doesn't create or destroy them.
resource "kubernetes_namespace" "clusterkeep_ui" {
  for_each = var.clusterkeep_ui_namespaces

  metadata {
    name = each.value
  }
}

# Nexus pull credentials for clusterkeep-ui's image, one Secret per
# namespace above. Same reasoning as the namespaces , this is registry
# auth wiring, not anything specific to the app itself.
resource "kubernetes_secret" "clusterkeep_ui_registry" {
  for_each = var.clusterkeep_ui_registry_username != "" ? var.clusterkeep_ui_namespaces : {}

  metadata {
    name      = "clusterkeep-ui-registry"
    namespace = kubernetes_namespace.clusterkeep_ui[each.key].metadata[0].name
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
