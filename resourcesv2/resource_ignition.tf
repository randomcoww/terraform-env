module "kubernetes-common" {
  source = "../modulesv2/kubernetes_common"

  cluster_name          = "default-cluster-012"
  s3_backup_aws_region  = "us-west-2"
  s3_etcd_backup_bucket = "randomcoww-etcd-backup"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  controller_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "controller")
  }

  worker_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "worker")
  }
}

module "gateway-common" {
  source = "../modulesv2/gateway_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  gateway_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "gateway")
  }
}

module "test-common" {
  source = "../modulesv2/test_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  test_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "test")
  }
}

module "kvm-common" {
  source = "../modulesv2/kvm_common"

  user              = local.user
  ssh_ca_public_key = tls_private_key.ssh-ca.public_key_openssh
  mtu               = local.mtu
  networks          = local.networks
  services          = local.services
  domains           = local.domains
  container_images  = local.container_images

  kvm_hosts = {
    for k in keys(local.hosts) :
    k => merge(local.hosts[k], {
      host_network = {
        for n in local.hosts[k].network :
        lookup(n, "alias", lookup(n, "network", "placeholder")) => n
      }
    })
    if contains(local.hosts[k].components, "kvm")
  }
}

##
## Write config to each matchbox host
## Hardcode each matchbox host until for_each module becomes available
##
module "ignition-kvm-0" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  test_params       = {}
  kvm_params        = {}
  renderer          = local.renderers.kvm-0
}

module "ignition-kvm-1" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  test_params       = {}
  kvm_params        = {}
  renderer          = local.renderers.kvm-1
}

module "ignition-desktop" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  test_params       = module.test-common.test_params
  kvm_params        = {}
  renderer          = local.renderers.desktop
}

# Build and test environment
module "ignition-local" {
  source = "../modulesv2/ignition"

  services          = local.services
  controller_params = module.kubernetes-common.controller_params
  worker_params     = module.kubernetes-common.worker_params
  gateway_params    = module.gateway-common.gateway_params
  test_params       = module.test-common.test_params
  kvm_params        = module.kvm-common.kvm_params
  renderer          = local.local_renderer
}

# Write admin kubeconfig file
resource "local_file" "kubeconfig-admin" {
  content = templatefile("${path.module}/../templates/manifest/kubeconfig_admin.yaml.tmpl", {
    cluster_name       = module.kubernetes-common.cluster_name
    ca_pem             = replace(base64encode(chomp(module.kubernetes-common.kubernetes_ca_pem)), "\n", "")
    cert_pem           = replace(base64encode(chomp(module.kubernetes-common.kubernetes_cert_pem)), "\n", "")
    private_key_pem    = replace(base64encode(chomp(module.kubernetes-common.kubernetes_private_key_pem)), "\n", "")
    apiserver_endpoint = module.kubernetes-common.apiserver_endpoint
  })
  filename = "output/${module.kubernetes-common.cluster_name}.kubeconfig"
}

locals {
  matchbox_renderers = {
    for k in keys(module.ignition-local.matchbox_rpc_endpoints) :
    k => {
      endpoint        = module.ignition-local.matchbox_rpc_endpoints[k]
      cert_pem        = module.ignition-local.matchbox_cert_pem
      private_key_pem = module.ignition-local.matchbox_private_key_pem
      ca_pem          = module.ignition-local.matchbox_ca_pem
    }
  }

  coreos_libvirt = {
    for k in keys(module.ignition-local.libvirt_endpoints) :
    k => {
      endpoint = module.ignition-local.libvirt_endpoints[k]
    }
  }
}