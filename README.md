docker build -t ubuntu-vm .
docker run -d --privileged --device /dev/kvm -p 6080:6080 -p 2222:2222 ubuntu-vm
