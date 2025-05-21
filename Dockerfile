FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    cloud-image-utils \
    genisoimage \
    wget \
    novnc \
    websockify \
    net-tools \
    openssh-client \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /novnc /opt/qemu /cloud-init

# Download Ubuntu 22.04 cloud image
RUN wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img -O /opt/qemu/ubuntu.img

# Create cloud-init meta-data
RUN echo 'instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm' > /cloud-init/meta-data

# Create cloud-init user-data with root password = root (hashed)
RUN cat <<EOF > /cloud-init/user-data
#cloud-config
disable_root: false
ssh_pwauth: true
users:
  - name: root
    lock_passwd: false
    passwd: \$6\$rDGvOBc5yATrVmjv\$gYuAkrJX3UvD3lzLD08RTpJ14F5HxPGcKmnS26A4IN0vnwPtDuzgWYzS1EQ96XwUcSLkLniG2yxS7Zofr2yDa.
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
chpasswd:
  expire: false
EOF

# Generate cloud-init seed ISO
RUN genisoimage -output /opt/qemu/seed.iso -volid cidata -joliet -rock /cloud-init/user-data /cloud-init/meta-data

# Download and install noVNC
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# Startup script
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

DISK="/data/vm.raw"
IMG="/opt/qemu/ubuntu.img"
SEED="/opt/qemu/seed.iso"

if [ ! -f "$DISK" ]; then
    echo "Creating VM disk from cloud image..."
    qemu-img convert -f qcow2 -O raw "$IMG" "$DISK"
    qemu-img resize "$DISK" 20G
fi

echo "Starting QEMU VM..."

qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -m 2048 \
    -smp 2 \
    -drive file="$DISK",format=raw,if=virtio \
    -drive file="$SEED",format=raw,if=virtio \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -vnc :0 \
    -serial mon:stdio &

sleep 3

echo "Starting noVNC..."

websockify --web /novnc 6080 localhost:5900

EOF

RUN chmod +x /start.sh

VOLUME /data

EXPOSE 6080 2222

CMD ["/start.sh"]
