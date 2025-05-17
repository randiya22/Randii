FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update && apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    novnc \
    websockify \
    wget \
    net-tools \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*


RUN mkdir -p /data /novnc /opt/qemu


ADD https://releases.ubuntu.com/focal/ubuntu-20.04.6-live-server-amd64.iso /opt/qemu/ubuntu.iso


RUN wget https://github.com/novnc/noVNC/archive/refs/heads/master.zip -O /tmp/novnc.zip && \
    unzip /tmp/novnc.zip -d /tmp && \
    mv /tmp/noVNC-master/* /novnc && \
    rm -rf /tmp/novnc.zip /tmp/noVNC-master


RUN cat <<'EOF' > /start.sh
#!/bin/bash
set -e

DISK="/data/disk.qcow2"
ISO="/opt/qemu/ubuntu.iso"
BOOT_ONCE_FLAG="/data/.booted"

# Create virtual disk if not exists
if [ ! -f "$DISK" ]; then
    echo "Creating disk image..."
    qemu-img create -f qcow2 "$DISK" 100G
fi

# Decide whether to boot from CD-ROM or disk only
if [ ! -f "$BOOT_ONCE_FLAG" ]; then
    echo "First-time boot with ISO"
    BOOT_OPTS="-cdrom $ISO"
    touch "$BOOT_ONCE_FLAG"
else
    echo "Subsequent boot without ISO"
    BOOT_OPTS=""
fi


qemu-system-x86_64 \
    -enable-kvm \
    -cpu host \
    -m 7400 \
    -smp 8 \
    -vga virtio \
    $BOOT_OPTS \
    -drive file="$DISK",format=qcow2,if=virtio \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -device virtio-net,netdev=net0 \
    -vnc :0 &

sleep 5
websockify --web /novnc 6080 localhost:5900 &

echo "================================================"
echo " 🖥️  Access your VM at: http://localhost:6080"
echo " 🔐 This image is made by hopingboyz"
echo "================================================"

tail -f /dev/null
EOF


RUN chmod +x /start.sh


VOLUME /data


EXPOSE 6080 2222

CMD ["/start.sh"]
