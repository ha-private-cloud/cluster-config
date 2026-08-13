# Mirrors nfs-storage VM console credentials (from proxmox-tofu) into a Secret, reachable via kubectl.
data "terraform_remote_state" "proxmox_tofu" {
  backend = "local"

  config = {
    path = "${path.module}/../proxmox-tofu/terraform.tfstate"
  }
}

resource "kubernetes_namespace" "infra" {
  metadata {
    name = "infra"
  }
}

resource "kubernetes_secret" "nfs_storage_credentials" {
  for_each = data.terraform_remote_state.proxmox_tofu.outputs.nfs_console_password

  metadata {
    name      = "nfs-storage-credentials-${each.key}"
    namespace = kubernetes_namespace.infra.metadata[0].name
  }

  data = {
    username = data.terraform_remote_state.proxmox_tofu.outputs.nfs_admin_username
    password = each.value
  }
}
