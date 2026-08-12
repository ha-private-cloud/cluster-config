resource "kubernetes_namespace" "csi_driver_nfs" {
  metadata {
    name = var.csi_driver_nfs_namespace
    # Node plugin needs privileged host mounts; same PSA exemption as ingress-nginx.
    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "helm_release" "csi_driver_nfs" {
  name       = "csi-driver-nfs"
  repository = "https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts"
  chart      = "csi-driver-nfs"
  version    = var.csi_driver_nfs_chart_version
  namespace  = kubernetes_namespace.csi_driver_nfs.metadata[0].name

  values = [
    templatefile("${path.module}/values/csi-driver-nfs.yaml.tftpl", {
      nfs_server_address = var.nfs_server_address
      nfs_export_path    = var.nfs_export_path
    })
  ]
}
