output "libvirt_domains" {
  value = {
    for host, params in var.hosts :
    host => chomp(templatefile(var.domain_template, {
      name                  = host
      memory                = params.memory
      vcpu                  = params.vcpu
      network               = params.network
      hostdev               = params.hostdev
      disk                  = params.disk
      networks              = var.networks
      boot_image_mount_path = var.boot_image_mount_path
    }))
  }
}