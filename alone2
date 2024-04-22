#!/bin/bash

# 创建tmux会话并启动 Titan daemon
tmux new -s titan -d "cd titan_v0.1.16_linux_amd64 && ./titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0"

# 等待5秒
sleep 5

# 在后台创建新的tmux会话并执行 bind 操作
tmux new -s titan_bind -d "cd titan_v0.1.16_linux_amd64 && ./titan-edge bind --hash=8DD1ECF9-7717-4776-95FD-174D3D60B33B https://api-test1.container1.titannet.io/api/v2/device/binding"
