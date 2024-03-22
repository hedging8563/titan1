#!/bin/bash

# Check if running with root privileges, if not, exit
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root or using sudo."
    exit 1
fi

sudo -i

wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.14/titan_v0.1.14_linux_amd64.tar.gz
tar -zxvf titan_v0.1.14_linux_amd64.tar.gz

sleep 20

chmod u+x titan_v0.1.14_linux_amd64
cd titan_v0.1.14_linux_amd64

tmux new -s titan

./titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0
./titan-edge bind --hash=369BF4FD-0A3F-4EEF-B280-CE7A9C527907 https://api-test1.container1.titannet.io/api/v2/device/binding
