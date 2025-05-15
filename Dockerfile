# Use Ubuntu 24.04 as base
FROM ubuntu:24.04

# Install minimal dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    qemu-system-x86 \
    qemu-utils \
    wget \
    python3 \
    novnc \
    websockify \
    && rm -rf /var/lib/apt/lists/*

# Download the LATEST Ubuntu Server ISO (will prompt during install)
RUN wget -q https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso -O /ubuntu.iso

# Create startup script
RUN echo '#!/bin/bash\n\
\n\
# Create blank 20GB disk image\n\
qemu-img create -f qcow2 /disk.qcow2 20G\n\
\n\
# Start QEMU with full interactive installation\n\
qemu-system-x86_64 \\\n\
    -enable-kvm \\\n\
    -cdrom /ubuntu.iso \\\n\
    -drive file=/disk.qcow2,format=qcow2 \\\n\
    -m 4G \\\n\
    -smp 4 \\\n\
    -device virtio-net,netdev=net0 \\\n\
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \\\n\
    -vnc 0.0.0.0:0 \\\n\
    -nographic &\n\
\n\
# Start noVNC\n\
websockify --web /usr/share/novnc/ 6080 localhost:5900 &\n\
\n\
echo "================================================"\n\
echo "Ubuntu Server Installation Starting..."\n\
echo "1. Connect to VNC: http://localhost:6080"\n\
echo "2. Complete the interactive installation"\n\
echo "3. Set your username/password when prompted"\n\
echo "4. After reboot, SSH will be available on port 2222"\n\
echo "================================================"\n\
\n\
tail -f /dev/null\n\
' > /start-vm.sh && chmod +x /start-vm.sh

EXPOSE 6080 2222

CMD ["/start-vm.sh"]
