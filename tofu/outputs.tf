output "headlamp_url" {
  description = "URL for the Headlamp UI once DNS/hosts is configured."
  value       = "https://${var.headlamp_hostname}"
}

output "headlamp_token_command" {
  description = "Command to mint a login token for the Headlamp UI, using the chart's own default ServiceAccount (bound to cluster-admin)."
  value       = "kubectl create token headlamp -n ${kubernetes_namespace.headlamp.metadata[0].name}"
}

output "etc_hosts_note" {
  description = "Reminder to map the hostname to a worker node IP."
  value       = "Add to /etc/hosts: '<worker-node-ip> ${var.headlamp_hostname}' (e.g. one of the Talos worker IPs , ingress-nginx runs as a DaemonSet with hostNetwork on the worker nodes)."
}

output "nexus_url" {
  description = "URL for the Nexus web UI once DNS/hosts is configured."
  value       = "https://${var.nexus_hostname}"
}

output "nexus_admin_password_command" {
  description = "Command to read Nexus's generated initial admin password (valid until changed on first login)."
  value       = "kubectl exec -n ${kubernetes_namespace.nexus.metadata[0].name} deploy/nexus -- cat /nexus-data/admin.password"
}

output "clusterkeep_ui_registry_username" {
  description = "Nexus pull credentials for clusterkeep-ui , read by that repo's Tofu via terraform_remote_state to query the registry for the latest tag on each apply."
  value       = var.clusterkeep_ui_registry_username
}

output "clusterkeep_ui_registry_password" {
  description = "See clusterkeep_ui_registry_username."
  value       = var.clusterkeep_ui_registry_password
  sensitive   = true
}

output "nexus_docker_registry" {
  description = "Host:port every app's Helm chart should use as image.repository's registry. Requires a \"docker (hosted)\" repository created in the Nexus UI with its HTTP port set to match, and ../proxmox-tofu/talos-registry-patch.yaml applied to every node (see README)."
  value       = "${var.nexus_docker_hostname}:${var.nexus_docker_port}"
}
