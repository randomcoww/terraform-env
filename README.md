## Terraform configs for provisioning homelab resources

All VMs run on [CoreOS Container Linux](https://coreos.com/os/docs/latest/) using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration.

Config rendering is handled by [CoreOS Matchbox](https://github.com/coreos/matchbox/).

[HashiCorp Terraform](https://www.hashicorp.com/products/terraform) is used in all steps. The following plugins are used:
- [Matchbox plugin](https://github.com/coreos/terraform-provider-matchbox)
- [Syncthing devices plugin](https://github.com/randomcoww/terraform-provider-syncthing)

S3 is used as the backend store for Terraform and requires AWS access from the dev environment.

The hypervisor and all VMs run on RAM disk and keep no state. Any persistent configuration is intended to live on shared NFS (at 192.168.126.251 in my case).

### Renderer

Generates minimal configuration for standing up a local Matchbox server that accepts configuration from terraform and provides rendered configuration over http.
This is used to render configuration that cannot be provided over PXE (i.e. provisioner for the PXE server itself and hypervisor that they run on).

Start local Matchbox on Docker
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
export FEDORA_RELEASE=30

wget \
    https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Server/x86_64/iso/Fedora-Server-netinst-x86_64-$FEDORA_RELEASE-1.2.iso

sudo livemedia-creator \
    --make-iso \
    --iso=./Fedora-Server-netinst-x86_64-$FEDORA_RELEASE-1.2.iso \
    --project Fedora \
    --volid vm \
    --releasever $FEDORA_RELEASE \
    --title vm \
    --resultdir ./result \
    --tmp . \
    --ks=./vm-0.ks \
    --no-virt \
    --lorax-templates ./lorax-vm

sudo livemedia-creator \
    --make-iso \
    --iso=./Fedora-Server-netinst-x86_64-$FEDORA_RELEASE-1.2.iso \
    --project Fedora \
    --volid vm \
    --releasever $FEDORA_RELEASE \
    --title vm \
    --resultdir ./result \
    --tmp . \
    --ks=./vm-1.ks \
    --no-virt \
    --lorax-templates ./lorax-vm

sudo livemedia-creator \
    --make-iso \
    --iso=./Fedora-Server-netinst-x86_64-$FEDORA_RELEASE-1.2.iso \
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

These images can be written to a USB flash drive.

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

Provisioners need Container Linux PXE boot images on the host filesystem to boot. Looking for possible workarounds to this such as booting a more miminal GRUB image that is able to download these at boot time.

**TODO**: Investigate
* https://lists.gnu.org/archive/html/help-grub/2013-08/msg00037.html
* http://www.manobit.com/pxe-multi-boot-server-using-grub2-on-mikrotik-routeros-bios-and-efi-support/

Compatible KVM libvirt configurations are in [env-provisioner](https://github.com/randomcoww/env-provisioner). I currently have no automation for defining and starting VMs.
```bash
virsh define provisioner-0.xml
virsh define provisioner-1.xml

virsh start provisioner-0
...
```

The provisioner steps are generally ugly and need revising.

DHCP (Kea) instances run in hot-standby. Matchbox instances share configuration over Syncthing. This data is lost if all instances are rebooted at the same time.

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

Built image can be written to a USB flash drive to boot live environment. Currently `/localhome` containing persistent user home directory is overlay mounted with ZFS.

### SSH CA

Outputs SSH CA key that can be used to sign public keys for accessing all servers built using this terraform.

```bash
cd resources
terraform apply \
    -target=local_file.ssh_ca_key
```
