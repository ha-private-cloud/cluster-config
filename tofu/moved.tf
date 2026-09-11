# Remove once this has been applied for real - keeps the pre-existing single auth-api namespace from being destroyed and recreated under the new per-environment for_each.
moved {
  from = kubernetes_namespace.auth_api
  to   = kubernetes_namespace.auth_api["default"]
}

moved {
  from = kubernetes_secret.auth_api_registry[0]
  to   = kubernetes_secret.auth_api_registry["default"]
}
