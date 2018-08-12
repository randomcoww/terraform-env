##
## kube controller ignition renderer
##
resource "matchbox_profile" "ignition_controller" {
  name                   = "host_controller"
  container_linux_config = "${file("${path.module}/templates/ignition/controller.ign.tmpl")}"
  kernel                 = "/assets/coreos/${var.container_linux_version}/coreos_production_pxe.vmlinuz"

  initrd = [
    "/assets/coreos/${var.container_linux_version}/coreos_production_pxe_image.cpio.gz",
  ]

  args = [
    "coreos.config.url=http://${var.matchbox_vip}:${var.matchbox_http_port}/ignition?mac=$${mac:hexhyp}",
    "coreos.first_boot=yes",
    "console=hvc0",
    "coreos.autologin",
  ]
}

resource "matchbox_group" "ignition_controller" {
  count   = "${length(var.controller_hosts)}"

  name    = "host_${var.controller_hosts[count.index]}"
  profile = "${matchbox_profile.ignition_controller.name}"

  selector {
    mac = "${var.controller_macs[count.index]}"
  }

  metadata {
    hostname           = "${var.controller_hosts[count.index]}"
    hyperkube_image    = "${var.hyperkube_image}"
    ssh_authorized_key = "cert-authority ${chomp(tls_private_key.ssh_ca.public_key_openssh)}"
    default_user       = "${var.default_user}"
    manifest_url       = "http://${var.matchbox_vip}:${var.matchbox_http_port}/generic?manifest=${matchbox_profile.manifest_controller.name}"
    apiserver_url      = "https://127.0.0.1:${var.apiserver_secure_port}"
    cluster_name       = "${var.cluster_name}"

    host_ip = "${var.controller_ips[count.index]}"
    host_if = "${var.controller_if}"
    host_netmask = "${var.netmask}"

    kubernetes_path = "${var.kubernetes_path}"
    docker_opts     = "--log-driver=journald"

    tls_ca                     = "${replace(tls_self_signed_cert.root.cert_pem, "\n", "\\n")}"
    tls_ca_key                 = "${replace(tls_private_key.root.private_key_pem, "\n", "\\n")}"
    tls_kubernetes             = "${replace(tls_locally_signed_cert.kubernetes.cert_pem, "\n", "\\n")}"
    tls_kubernetes_key         = "${replace(tls_private_key.kubernetes.private_key_pem, "\n", "\\n")}"
    tls_controller_manager     = "${replace(tls_locally_signed_cert.controller_manager.cert_pem, "\n", "\\n")}"
    tls_controller_manager_key = "${replace(tls_private_key.controller_manager.private_key_pem, "\n", "\\n")}"
    tls_scheduler              = "${replace(tls_locally_signed_cert.scheduler.cert_pem, "\n", "\\n")}"
    tls_scheduler_key          = "${replace(tls_private_key.scheduler.private_key_pem, "\n", "\\n")}"
    tls_service_account        = "${replace(tls_private_key.service_account.public_key_pem, "\n", "\\n")}"
    tls_service_account_key    = "${replace(tls_private_key.service_account.private_key_pem, "\n", "\\n")}"
  }
}