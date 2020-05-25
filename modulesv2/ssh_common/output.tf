output "ssh_ca_private_key" {
  value = tls_private_key.ssh-ca.private_key_pem
}

output "ssh_ca_authorized_key" {
  value = tls_private_key.ssh-ca.public_key_openssh
}

output "ssh_client_certificate" {
  value = length(sshca_client_cert.ssh-client) > 0 ? sshca_client_cert.ssh-client[0].cert_authorized_key : ""
}

output "templates" {
  value = {
    for host, params in var.ssh_hosts :
    host => [
      for template in var.ssh_templates :
      templatefile(template, {
        user                  = var.user
        ssh_ca_authorized_key = tls_private_key.ssh-ca.public_key_openssh
        ssh_host_private_key  = replace(tls_private_key.ssh-host[host].private_key_pem, "\n", "\\n")
        ssh_host_public_key   = tls_private_key.ssh-host[host].public_key_openssh
        ssh_host_certificate  = sshca_host_cert.ssh-host[host].cert_authorized_key
      })
    ]
  }
}