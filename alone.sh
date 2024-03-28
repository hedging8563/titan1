#!/bin/bash

# 下载并解压 Titan 文件
wget https://github.com/Titannet-dao/titan-node/releases/download/v0.1.15/titan_v0.1.15_linux_amd64.tar.gz
tar -zxvf titan_v0.1.15_linux_amd64.tar.gz

# 等待10秒
sleep 10

# 赋予执行权限
chmod u+x titan_v0.1.15_linux_amd64

# 创建tmux会话并启动 Titan daemon
tmux new -s titan -d "cd titan_v0.1.14_linux_amd64 && ./titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0"

# 等待5秒
sleep 5

# 在后台创建新的tmux会话并执行 bind 操作
tmux new -s titan_bind -d "cd titan_v0.1.14_linux_amd64 && ./titan-edge bind --hash=369BF4FD-0A3F-4EEF-B280-CE7A9C527907 https://api-test1.container1.titannet.io/api/v2/device/binding"
