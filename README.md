## Terraform configs for provisioning homelab resources

All VMs run on [CoreOS Container Linux](https://coreos.com/os/docs/latest/) using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration.

Config rendering is handled by [CoreOS Matchbox](https://github.com/coreos/matchbox/).

[HashiCorp Terraform](https://www.hashicorp.com/products/terraform) is used in all steps. The following plugins are used:
- [Matchbox plugin](https://github.com/coreos/terraform-provider-matchbox)
- [Syncthing devices plugin](https://github.com/randomcoww/terraform-provider-syncthing)

S3 is used as the backend store for Terraform and requires AWS access from the dev environment.

The hypervisor and all VMs run on RAM disk and keep no state. Hardware hosts participate in a [Minio](https://min.io/) cluster for persistent storage over S3 API or over iSCSI + [s3backer](https://github.com/archiecobbs/s3backer) on top of Minio.

### Renderer

Generates minimal configuration for standing up a local Matchbox server that accepts configuration from terraform and provides rendered configuration over http.
This is used to render configuration that cannot be provided over PXE (i.e. provisioner for the PXE server itself and hypervisor that they run on).

Start local Matchbox in a container (using podman)
```bash
cd resources
./run_matchbox.sh
```

Service runs at:
```
http://127.0.0.1:8080
```

### Provisioner

Generates configuration for the PXE boot environment on the local Matchbox instance. Provisioner consists of a network gateway with Nftables and a PXE environment with a Matchbox instance of its own, DHCP and TFTP.

```bash
cd resources
terraform apply \
    -target=module.provisioner \
    -target=module.hardware
```

#### Hypervisor and desktop images

Generate hypervisor images:
```bash
cd build
export FEDORA_RELEASE=31
export ISO_FILE=./Fedora-Server-netinst-x86_64-31-1.9.iso

wget \
    https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Server/x86_64/iso/Fedora-Server-netinst-x86_64-$FEDORA_RELEASE-1.2.iso

sudo livemedia-creator \
    --make-iso \
    --iso=$ISO_FILE \
    --project Fedora \
    --volid kvm \
    --releasever $FEDORA_RELEASE \
    --title kvm \
    --resultdir ./result \
    --tmp . \
    --ks=./kvm-0.ks \
    --no-virt \
    --lorax-templates ./lorax-kvm

sudo livemedia-creator \
    --make-iso \
    --iso=$ISO_FILE \
    --project Fedora \
    --volid kvm \
    --releasever $FEDORA_RELEASE \
    --title kvm \
    --resultdir ./result \
    --tmp . \
    --ks=./kvm-1.ks \
    --no-virt \
    --lorax-templates ./lorax-kvm

sudo livemedia-creator \
    --make-iso \
    --iso=$ISO_FILE \
    --project Fedora \
    --volid desktop \
    --releasever $FEDORA_RELEASE \
    --title desktop \
    --resultdir ./result \
    --tmp . \
    --ks=./desktop-0.ks \
    --no-virt \
    --lorax-templates ./lorax-desktop
```

These images are bootable and intended for running from a USB flash drive. Image is copied to and runs entirely in RAM. There is no data persistence on these images.

Hypervisor hosts vm-* are able to run static pods. Currenrly this is used to run Minio. This may move to being served over http from provisioner Matchbox.

#### Provisioner VM

Provisioner VMs serving PXE also serve as the WAN gateway intended to boot on ISP DHCP. Ignition configuration is pushed to and served from [env-provisioner](https://github.com/randomcoww/env-provisioner) at boot time.

Copy and push CoreOS ignition configs to repo:
```bash
git clone git@github.com:randomcoww/env-provisioner.git
cd env-provisioner/ignition

wget -O provisioner-0.ign \
    http://127.0.0.1:8080/ignition?ign=provisioner-0

wget -O provisioner-1.ign \
    http://127.0.0.1:8080/ignition?ign=provisioner-1
    
git add provisioner-0.ign provisioner-1.ign
...
```

Compatible KVM libvirt configurations are in [env-provisioner](https://github.com/randomcoww/env-provisioner). Boot kernel and initrd images are Container Linux PXE images available from CoreOS. The latest of these are baked into the hypervisor at time of building these images.

I currently have no automation for defining and starting VMs. They are defined and started manually:

```bash
virsh define provisioner-0.xml
virsh define provisioner-1.xml

virsh start provisioner-0
...
```

DHCP (Kea) instances run in hot-standby. Matchbox instances share configuration over Syncthing. This data is lost if all instances are rebooted at the same time, but can be regenerated by running `terraform apply`.

![provisioner](images/provisioner.png)

### Kubernetes and remaining environment

Generate a Kubernetes cluster of 3 controller/etcd nodes and 2 worker nodes.

Etcd, in addition to most other services in my lab, runs on RAM disk, but is periodically backed up to S3 and recovered as needed. Custom [etcd-wrapper](https://github.com/randomcoww/etcd-wrapper) tool is used to manage this.

Populate provisioner Matchbox instance:
```bash
cd resources
terraform apply \
    -target=module.kubernetes_cluster \
    -target=local_file.admin_kubeconfig
```

Compatible KVM libvirt configurations are in [env-provisioner](https://github.com/randomcoww/env-provisioner). I currently have no automation for defining and starting VMs.
```bash
virsh define controller-0.xml
virsh define controller-1.xml
virsh define controller-2.xml
virsh define worker-0.xml
virsh define worker-1.xml

virsh start controller-0
...
```

Admin kubeconfig:
```
setup_environment/output/kube-cluster/<name_of_cluster>/admin.kubeconfig
```


### SSH CA

Outputs SSH CA key that can be used to sign public keys for accessing all servers built using this terraform.

```bash
cd resources
terraform apply \
    -target=local_file.ssh_ca_key
```
