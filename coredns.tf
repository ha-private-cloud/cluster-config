# *.talos.lab only resolves via workstations' /etc/hosts, but Headlamp's
# pod needs to resolve auth.talos.lab in-cluster for OIDC discovery. This
# patches in static entries pointing at ingress-nginx's ClusterIP.
data "kubernetes_service" "ingress_nginx_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }

  depends_on = [helm_release.ingress_nginx]
}

resource "kubernetes_config_map_v1_data" "coredns_hosts" {
  metadata {
    name      = "coredns"
    namespace = "kube-system"
  }

  data = {
    Corefile = <<-EOT
      .:53 {
          errors
          health {
              lameduck 5s
          }
          ready
          log . {
              class error
          }
          prometheus :9153
          hosts {
              ${data.kubernetes_service.ingress_nginx_controller.spec[0].cluster_ip} ${var.authentik_hostname}
              ${data.kubernetes_service.ingress_nginx_controller.spec[0].cluster_ip} ${var.headlamp_hostname}
              fallthrough
          }

          kubernetes cluster.local in-addr.arpa ip6.arpa {
              pods insecure
              fallthrough in-addr.arpa ip6.arpa
              ttl 30
          }
          forward . /etc/resolv.conf {
             max_concurrent 1000
          }
          cache 30 {
             disable success cluster.local
             disable denial cluster.local
          }
          loop
          reload
          loadbalance
      }
    EOT
  }

  force = true
}
