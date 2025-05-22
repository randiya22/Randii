FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install only required packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    cloud-image-utils \
    genisoimage \
    novnc \
    websockify \
    curl \
    unzip \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

# Setup directories
RUN mkdir -p /data /novnc /opt/qemu /cloud-init

# Download Ubuntu 22.04 cloud image
RUN curl -L https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -o /opt/qemu/ubuntu.img

# Cloud-init config
RUN echo 'instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm' > /cloud-init/meta-data

# Root password = rootpass (hashed)
RUN cat <<EOF > /cloud-init/user-data
#cloud-config
users:
  - default
  - name: root
    lock_passwd: false
    passwd: \$6\$Um/UNUmq1rYsc0N7\$IPjqZ3oBx1isZfBT99V06mwUyFZPKGIi8bsxlf4W9Ir9nS3aB0/u.gVSC6s9HDZBhWi84swg0Lt8bcTjJlaLg.
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false
EOF

# Create cloud-init ISO
RUN genisoimage -output /opt/qemu/seed.iso -volid cidata -joliet -rock /cloud-init/user-data /cloud-init/meta-data

# Get stable noVNC
RUN curl -L https://github.com/novnc/noVNC/archive/refs/tags/v1.3.0.zip -o /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-1.3.0/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-1.3.0

# Create start script
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

DISK="/data/vm.raw"
IMG="/opt/qemu/ubuntu.img"
SEED="/opt/qemu/seed.iso"

# Create persistent VM disk
if [ ! -f "$DISK" ]; then
    echo "Creating VM disk..."
    qemu-img convert -f qcow2 -O raw "$IMG" "$DISK"
    qemu-img resize "$DISK" 20G
fi

# Start VM with KVM, fast virtio drivers
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 2 \
    -m 2048 \
    -drive file="$DISK",format=raw,if=virtio,cache=writeback \
    -drive file="$SEED",format=raw,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=net0 \
    -vga virtio \
    -display vnc=:0 \
    -nographic &

sleep 2

# Start noVNC
websockify --web=/novnc 6080 localhost:5900 &

echo "================================================"
echo " 🖥️  VNC: http://localhost:6080/vnc.html"
echo " 🔐 SSH: ssh root@localhost -p 2222"
echo " 🧾 Login: root / rootpass"
echo "================================================"

wait
EOF

RUN chmod +x /start.sh

VOLUME /data

EXPOSE 6080 2222

CMD ["/start.sh"]
