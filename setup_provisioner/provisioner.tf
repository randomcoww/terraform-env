# Matchbox configs for PXE environment with matchbox renderer
module "provisioner" {
  source = "../modules/provisioner"

  output_path = "matchbox"

  ## user (default container linux)
  default_user      = "core"
  ssh_ca_public_key = "${tls_private_key.ssh_ca.public_key_openssh}"

  ## DHCP domain
  domain_name = "host.internal"

  ## host configs
  provisioner_hosts     = ["provisioner-0", "provisioner-1"]
  provisioner_lan_ips   = ["192.168.62.217", "192.168.62.218"]
  provisioner_store_ips = ["192.168.126.217", "192.168.126.218"]
  provisioner_sync_ips  = ["192.168.190.1", "192.168.190.2"]
  kea_ha_roles          = ["primary", "standby"]
  provisioner_store_if  = "eth0"
  provisioner_lan_if    = "eth1"
  provisioner_sync_if   = "eth2"
  provisioner_wan_if    = "eth3"
  provisioner_vwan_if   = "eth4"
  mtu                   = "9000"

  ## images
  hyperkube_image  = "gcr.io/google_containers/hyperkube:${local.kubernetes_version}"
  keepalived_image = "randomcoww/keepalived:20190119.01"
  unbound_image    = "randomcoww/unbound:20190119.01"
  nftables_image   = "randomcoww/nftables:20190119.01"
  kea_image        = "randomcoww/kea:20190119.01"
  tftpd_image      = "randomcoww/tftpd_ipxe:20190119.01"
  matchbox_image   = "quay.io/coreos/matchbox:latest"
  syncthing_image  = "randomcoww/syncthing:20190119.01"

  ## ports
  matchbox_http_port = "58080"
  matchbox_rpc_port  = "58081"

  ## vip
  store_gateway_vip = "192.168.126.240"
  lan_gateway_vip   = "192.168.62.240"
  dns_vip           = "192.168.126.241"
  matchbox_vip      = "192.168.126.242"
  backup_dns_ip     = "9.9.9.9"

  ## ip ranges
  store_netmask       = "23"
  lan_netmask         = "23"
  sync_netmask        = "29"
  store_ip_range      = "192.168.126.0/23"
  lan_ip_range        = "192.168.62.0/23"
  sync_ip_range       = "192.168.190.0/29"
  store_dhcp_ip_range = "192.168.126.64/26"
  lan_dhcp_ip_range   = "192.168.62.64/26"

  ## renderer provisioning access
  renderer_endpoint        = "${local.renderer_endpoint}"
  renderer_cert_pem        = "${local.renderer_cert_pem}"
  renderer_private_key_pem = "${local.renderer_private_key_pem}"
  renderer_ca_pem          = "${local.renderer_ca_pem}"
}
