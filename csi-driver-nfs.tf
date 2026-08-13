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
    file("${path.module}/values/csi-driver-nfs.yaml.tftpl")
  ]
}

resource "kubernetes_storage_class_v1" "nfs" {
  for_each = var.nfs_servers

  metadata {
    name = each.key
    annotations = each.value.default ? {
      "storageclass.kubernetes.io/is-default-class" = "true"
    } : {}
  }

  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = "Retain"
  volume_binding_mode = "Immediate"
  mount_options       = ["nfsvers=4.1"]

  parameters = {
    server = each.value.address
    share  = each.value.export_path
    # Each PVC gets its own subdirectory under the export, so unrelated
    # workloads sharing this one NFS export don't collide.
    subDir           = "$${pvc.metadata.namespace}-$${pvc.metadata.name}"
    mountPermissions = "0770"
  }

  depends_on = [helm_release.csi_driver_nfs]
}
