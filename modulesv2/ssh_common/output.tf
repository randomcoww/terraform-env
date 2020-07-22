output "client_params" {
  value = {
    ssh_ca_authorized_key  = tls_private_key.ssh-ca.public_key_openssh
    ssh_client_certificate = length(ssh_client_cert.ssh-client) > 0 ? ssh_client_cert.ssh-client[0].cert_authorized_key : ""
  }
}

output "templates" {
  value = {
    for host, params in var.hosts :
    host => [
      for template in var.templates :
      templatefile(template, {
        user                  = var.user
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
        ssh_host_private_key  = replace(tls_private_key.ssh-host[host].private_key_pem, "\n", "\\n")
        ssh_host_public_key   = tls_private_key.ssh-host[host].public_key_openssh
        ssh_host_certificate  = ssh_host_cert.ssh-host[host].cert_authorized_key
      })
    ]
  }
}

output "addons" {
  value = {}
}