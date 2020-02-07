## Terraform configs for provisioning homelab resources

### Run local matchbox server

Configurations for creating hypervisor images are generated on a local [Matchbox](https://github.com/coreos/matchbox/) instance. This will generate necessary TLS certs and start a local Matchbox instance using Podman:

```bash
cd resourcesv2
./run_renderer.sh
```

### Setup SSH access

Write SSH CA private key to sign a key for accessing the hypervisor over `virsh` and `ssh`:

```bash
cd resourcesv2
terraform apply -target=local_file.ssh-ca-key
```

Sign an existing key:

```
CA=$(pwd)/output/ssh-ca-key.pem
KEY=$HOME/.ssh/id_ecdsa.pub
USER=$(whoami)

chmod 400 $CA
ssh-keygen -s $CA -I $USER -n core -V +1w -z 1 $KEY
```

### Create hypervisor images

Hypervisor images are live USB disks created using Kickstart and livemedia-creator. Generate Kickstart configuration to local Matchbox server:

```bash
cd resourcesv2
terraform apply -target=module.kickstart
```

Generate USB images for hypervisor hosts:

```bash
cd build/kickstart
export FEDORA_RELEASE=31
export ISO_FILE=Fedora-Server-netinst-x86_64-31-1.9.iso

wget \
    https://download.fedoraproject.org/pub/fedora/linux/releases/$FEDORA_RELEASE/Server/x86_64/iso/$ISO_FILE

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
```

Write boot image to disk after each run:

```
sudo dd if=result/images/boot.iso of=/dev/sdb bs=4k
```

Image for the desktop (admin) PC can also be generated using this method. This image will trust the internal CA.

```
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

### Generate configuration on hypervisor hosts

Each hypervisor runs a PXE boot environment on an internal network for provisioning VMs local to the host. VMs run [Container Linux](https://coreos.com/os/docs/latest/) using [Ignition](https://coreos.com/ignition/docs/latest/) for boot time configuration.

Ignition configuration is generated on each hypervisor as follows:

```bash
cd resourcesv2
terraform apply \
    -target=module.ignition-kvm-0 \
    -target=module.ignition-kvm-1 \
    -target=module.ignition-desktop-0
```

Define VMs on each hypervisor:

```bash
cd resourcesv2
terraform apply \
    -target=module.libvirt-kvm-0 \
    -target=module.libvirt-kvm-1 \
    -target=module.libvirt-desktop-0
```

### Start gateway VMs

This will provide a basic infrastructure including NAT routing, DHCP and DNS.

```bash
virsh -c qemu+ssh://core@192.168.127.251/system start gateway-0
virsh -c qemu+ssh://core@192.168.127.252/system start gateway-1
```

### Start Kubernetes cluster VMs

Etcd data is restored from S3 on fresh start of a cluster if there is an existing backup. A backup is made every 30 minutes. Local data is discarded when the etcd container stops.

```bash
virsh -c qemu+ssh://core@192.168.127.251/system start controller-0
virsh -c qemu+ssh://core@192.168.127.252/system start controller-1
virsh -c qemu+ssh://core@192.168.127.251/system start controller-2

virsh -c qemu+ssh://core@192.168.127.251/system start worker-0
virsh -c qemu+ssh://core@192.168.127.252/system start worker-1
```

Write kubeconfig file:

```bash
terraform apply -target=local_file.kubeconfig-admin
export KUBECONFIG=$(pwd)/output/default-cluster-012.kubeconfig
```

### Generate basic Kubernetes addons

```bash
terraform apply -target=module.kubernetes-addons
```

Apply addons:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/website/master/content/en/examples/policy/privileged-psp.yaml
kubectl apply -f http://127.0.0.1:8080/generic?manifest=bootstrap
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kube-proxy
kubectl apply -f http://127.0.0.1:8080/generic?manifest=flannel
kubectl apply -f http://127.0.0.1:8080/generic?manifest=kapprover
kubectl apply -f http://127.0.0.1:8080/generic?manifest=coredns
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
kubectl apply -f http://127.0.0.1:8080/generic?manifest=metallb
kubectl apply -f http://127.0.0.1:8080/generic?secret=internal-tls
kubectl apply -f http://127.0.0.1:8080/generic?secret=minio-auth
kubectl apply -f http://127.0.0.1:8080/generic?secret=grafana-auth
```

### Deploy services on Kubernetes

Deploy [OpenEBS](https://www.openebs.io/):

Only Jiva is used (I don't have enough disks to dedicate to cStor). This is the same as https://openebs.github.io/charts/openebs-operator-1.6.0.yaml with some unused components removed.

```
cd reqourcesv2/manifests
kubectl apply -f openebs-operator.yaml
```

Deploy [Traefik](https://traefik.io/) ingress:

https://traefik-ui.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f traefik.yaml
```

Deploy monitoring:

https://grafana.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f prometheus.yaml
kubectl apply -f promtail.yaml
kubectl apply -f http://127.0.0.1:8080/generic?manifest=loki
kubectl apply -f grafana.yaml
```

Deploy [Minio](https://min.io/) storage controller:

https://minio.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f minio.yaml
```

Deploy MPD:

https://stream.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl apply -f mpd-rclone-pv.yaml
kubectl apply -f music-rclone-pv.yaml
kubectl apply -f mpd.yaml
```

Deploy Transmission:

https://tr.fuzzybunny.internal

```
cd reqourcesv2/manifests
kubectl create secret generic wireguard-config --from-file=wireguard-secret
kubectl apply -f ingest-rclone-pv.yaml
kubectl apply -f transmission.yaml
```

### Using tf-env container

Start renderer:

```
podman run -it --rm \
    -v $HOME/.aws:/root/.aws \
    -v $(pwd):/root/mnt \
    --net=host \
    randomcoww/tf-env start-renderer
```

or

```
podman run -it --rm \
    -e AWS_ACCESS_KEY_ID=id \
    -e AWS_SECRET_ACCESS_KEY=key \
    -v $(pwd):/root/mnt \
    --net=host \
    randomcoww/tf-env start-renderer
```

Wrapper for terraform calls:

```
podman run -it --rm \
    -v $HOME/.aws:/root/.aws \
    -v $(pwd):/root/mnt \
    --net=host \
    randomcoww/tf-env tf-wrapper
```
