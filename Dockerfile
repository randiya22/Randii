FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    cloud-image-utils \
    genisoimage \
    novnc \
    websockify \
    wget \
    net-tools \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data /novnc /opt/qemu /cloud-init

# Download Ubuntu Cloud image
RUN wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img -O /opt/qemu/ubuntu.img

# Cloud-init config
RUN echo 'instance-id: ubuntu-vm\nlocal-hostname: ubuntu-vm' > /cloud-init/meta-data

# Root password hash for "rootpass"
RUN cat <<EOF > /cloud-init/user-data
#cloud-config
users:
  - name: root
    lock_passwd: false
    passwd: \$6\$Um/UNUmq1rYsc0N7\$IPjqZ3oBx1isZfBT99V06mwUyFZPKGIi8bsxlf4W9Ir9nS3aB0/u.gVSC6s9HDZBhWi84swg0Lt8bcTjJlaLg.
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_pwauth: true
disable_root: false
chpasswd:
  expire: false
  list: |
    root:rootpass
EOF

RUN genisoimage -output /opt/qemu/seed.iso -volid cidata -joliet -rock /cloud-init/user-data /cloud-init/meta-data

# Setup noVNC
RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master

# Start script
RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

DISK="/data/vm.raw"
IMG="/opt/qemu/ubuntu.img"
SEED="/opt/qemu/seed.iso"

# Create raw disk on first boot
if [ ! -f "$DISK" ]; then
    echo "Creating VM disk..."
    qemu-img convert -f qcow2 -O raw "$IMG" "$DISK"
    qemu-img resize "$DISK" 20G
fi

# Start QEMU with VNC
qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -smp 2 \
    -m 2048 \
    -drive file="$DISK",format=raw,if=virtio \
    -drive file="$SEED",format=raw,if=virtio \
    -device virtio-net,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -vga std \
    -vnc :0 &

sleep 3

# Start noVNC
websockify --web /novnc 6080 localhost:5900 &

echo "================================================"
echo " 🖥️  Access your VM at: http://localhost:6080"
echo " 🔐 SSH to your VM: ssh root@localhost -p 2222"
echo " 🧾 Username: root | Password: rootpass"
echo "================================================"

wait
EOF

RUN chmod +x /start.sh

VOLUME /data

EXPOSE 6080 2222

CMD ["/start.sh"]
