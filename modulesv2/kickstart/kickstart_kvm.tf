##
## KVM (HW) kickstart renderer
##
resource "matchbox_group" "ks-kvm" {
  for_each = var.kvm_hosts

  profile = matchbox_profile.generic-profile.name
  name    = each.key
  selector = {
    ks = each.key
  }
  metadata = {
    config = templatefile("${path.module}/../../templates/kickstart/kvm.ks.tmpl", {
      hostname           = each.key
      user               = var.user
      password           = var.password
      ssh_authorized_key = "cert-authority ${chomp(var.ssh_ca_public_key)}"

      networkd_priority = 30
      networks          = var.networks
      host_network      = each.value.network
      vlans = {
        store = {
          if = "en-store"
        }
        lan = {
          if = "en-lan"
        }
        sync = {
          if = "en-sync"
        }
        wan = {
          if = "en-wan"
        }
      }
      services      = var.services
      mtu           = var.mtu
      host_tap_vlan = "store"
      host_tap_if   = "host-tap"
      int_bridge_if = "en-int"
      int_dummy_if  = "int-dummy"
      int_tap_if    = "int-tap"

      certs_path               = "/etc/ssl/certs"
      matchbox_url             = "https://github.com/poseidon/matchbox/releases/download/v0.8.0/matchbox-v0.8.0-linux-amd64.tar.gz"
      matchbox_data_path       = "/var/lib/matchbox/data"
      matchbox_assets_path     = "/var/lib/matchbox/assets"
      tls_matchbox_ca          = chomp(tls_self_signed_cert.matchbox-ca.cert_pem)
      tls_matchbox             = chomp(tls_locally_signed_cert.matchbox[each.key].cert_pem)
      tls_matchbox_key         = chomp(tls_private_key.matchbox[each.key].private_key_pem)
      container_linux_base_url = "https://beta.release.core-os.net/amd64-usr/current"
      container_linux_kernel   = "coreos_production_pxe.vmlinuz"
      container_linux_image    = "coreos_production_pxe_image.cpio.gz"
    })
  }
}