<h1 align="center">Ubuntu 20.4 in Docker</h1>

## Installation
1. Clone the repository or download:
`git clone https://github.com/hopingboyz/ubuntuvm20.4`

3. go to directory:
`cd ubuntuvm20.04`

3. Run this :
`docker build -t qemu-ubuntu-vm .`

5. Run Ubuntu 20.04:
`docker run -it --rm --device /dev/kvm -p 6080:6080 -p 2221:2222 -v qemu-data:/data qemu-ubuntu-vm`
