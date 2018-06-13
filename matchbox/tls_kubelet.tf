##
## matchbox
##
resource "tls_private_key" "kubelet" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P521"
}

resource "tls_cert_request" "kubelet" {
  key_algorithm   = "${tls_private_key.kubelet.algorithm}"
  private_key_pem = "${tls_private_key.kubelet.private_key_pem}"

  subject {
    common_name  = "system:node:worker-0"
    organization = "system:nodes"
  }
}

resource "tls_locally_signed_cert" "kubelet" {
  cert_request_pem   = "${tls_cert_request.kubelet.cert_request_pem}"
  ca_key_algorithm   = "${tls_private_key.root.algorithm}"
  ca_private_key_pem = "${tls_private_key.root.private_key_pem}"
  ca_cert_pem        = "${tls_self_signed_cert.root.cert_pem}"

  validity_period_hours = 8760

  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
