#!/bin/bash
# 初始化变量

type=""
code=""
nfsurl=""
folder=""
already_install_NFS=2
containers=4 # 默认容器数量为4

# 显示帮助信息
show_help() {
    cat << EOF
 ###################################帮助信息#################################
Usage: ${0##*/} [--type TYPE] [--code CODE] [--nfsurl NFSURL] [--containers CONTAINERS] [-h]
    --type TYPE              安装模式：1 代表仅5个容器模式，2 代表主机+4个容器模式。
    --code CODE              titan-edge 绑定码（必填）。
    --nfsurl NFSURL          NFS URL，用于挂载(可不填)。
    --already_install_NFS    是否已经安装NFS，1:是 2：否。
    --containers CONTAINERS  需要管理的容器数量，默认为 4。
    -h                       显示此帮助信息并退出。
    \n###################################注意#################################
    NFS需要存储空间限制为2T（目前不知道官方支持最大的多少）
    NFS提前挂载目录为：/mnt/titan
    #######################################################################
    微信：checkHeart666 
    注册链接：https://test1.titannet.io/intiveRegister?code=wLFnFN
    官网：   https://titannet.io/
	存储服务 ： https://storage.titannet.io/
	测试节点控制台：  https://test1.titannet.io/
 	中文文档： https://titannet.gitbook.io/titan-network-cn
EOF
}

###################################函数区域#################################
# 检查并安装NFS客户端
install_nfs_client() {
	echo "******************检查NFS客户端中******************"
    if ! command -v mount.nfs &> /dev/null; then
    	echo "******************NFS客户端未安装，开始安装...******************"
        if [ -f /etc/lsb-release ]; then
            # 对于基于Debian的系统
            apt-get update && apt-get install -y nfs-common
        elif [ -f /etc/redhat-release ]; then
            # 对于基于RHEL的系统
            yum install -y nfs-utils
        else
         echo "******************不支持的Linux发行版******************"
            exit 1
        fi
    else
        echo "******************NFS客户端已安装******************"
    fi
}

# 检查并安装Cron服务
install_cron() {
   echo "******************检查cron服务依赖中******************"
    if ! command -v crontab &> /dev/null; then
        echo "******************Cron服务未安装，开始安装******************"
        if [ -f /etc/lsb-release ]; then
            # 对于基于Debian的系统
            apt-get update && apt-get install -y cron
        elif [ -f /etc/redhat-release ]; then
            # 对于基于RHEL的系统
            yum install -y cronie
        else
            echo "******************不支持的Linux发行版******************"
            exit 1
        fi
        systemctl enable cron
        systemctl start cron
        echo "******************Cron服务安装完成******************"
    else
        echo "******************Cron服务已安装******************"
    fi
}

# 动态创建并注册检查Docker容器的Cron任务
setup_cron_job() {
    local script_path="/usr/local/bin/check_titan.sh"
    # 创建检查并启动Docker容器的脚本
    cat > $script_path << EOF
#!/bin/bash
container_count=$containers
for i in \$(seq 1 \$containers); do
    container_name="titan-edge0\$i"
    if [ "\$(docker inspect -f '{{.State.Running}}' \$container_name 2>/dev/null)" != "true" ]; then
        echo "\$container_name is not running. Starting \$container_name..."
        docker start \$container_name
    fi
done
EOF
    # 赋予脚本执行权限
    chmod +x $script_path
    # 添加Cron任务，每5分钟执行一次
    (crontab -l 2>/dev/null; echo "*/5 * * * * $script_path") | crontab -
}

setup_host_daemon_job() {
    local script_path="/usr/local/bin/check_titan_daemon.sh"

    # 创建检查并启动titan-edge主机进程的脚本
    cat > $script_path << 'EOF'
#!/bin/bash

# 检查titan-edge主机进程是否正在运行
if pgrep -af "titan-edge daemon start" | grep -v "init" >/dev/null; then
    echo "titan-edge 主机进程正在运行."
else
    echo "titan-edge 主机进程未运行. 正在启动..."
    nohup titan-edge daemon start > /var/log/edge.log 2>&1 &
fi
EOF
    # 赋予脚本执行权限
    chmod +x $script_path
    # 添加Cron任务，每5分钟执行一次
    (crontab -l 2>/dev/null; echo "*/5 * * * * $script_path") | crontab -
}


# 挂载NFS
mount_nfs() {
    if [ -n "$nfsurl" ]; then
        echo "***************挂载NFS共享：$nfsurl 到 /mnt/titan"
        mkdir -p /mnt/titan
        mount -t nfs -o vers=4,minorversion=0,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport "$nfsurl":/ /mnt/titan
        if [ $? -eq 0 ]; then
       		echo "******************NFS挂载完成******************"
            folder="/mnt/titan"
        else
       		echo "******************NFS挂载失败******************"
            exit 1
        fi
    fi
}

# 随机生成16位字符串的函数
generate_random_string() {
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1
}


# 创建存储目录
create_storage_directories() {
	echo "******************Docker存储目录创建中******************"
    for i in $(seq 1 $containers)
    do
        mkdir -p "${folder}/storage-${i}"
    done
    echo "******************Docker存储目录创建完成******************"
}

# 并运行容器
run_containers() {
	echo "******************正在启动docker实例******************"
    for i in $(seq 1 $containers)
    do
        docker run --name titan-edge0$i -d -v "${folder}/storage-$i:/root/.titanedge" nezha123/titan-edge:1.0
    done
    echo "******************所有Docker实例启动完成******************"
}

# 安装ca-certificates并绑定设备
setup_and_bind() {
    for i in $(seq 1 $containers)
    do
	   echo "******************正在给docker实例更新CA证书******************"
        docker exec -i titan-edge0$i bash -c "apt-get update && apt-get install -y ca-certificates"
        echo "******************docker实例$titan-edge0$i更新CA证书完成******************"
        sleep 1
        echo "******************正在绑定个人身份码******************"
        docker exec -i titan-edge0$i bash -c "titan-edge bind --hash=$code https://api-test1.container1.titannet.io/api/v2/device/binding"
        echo "******************个人身份码绑定完成******************"
    done
    	echo "******************安装绑定完成，请稍后登录控制台查看节点******************"
}

install_docker(){
     if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            "debian"|"ubuntu")
                echo "******************在Debian/Ubuntu上安装Docker******************"
                sudo apt-get update
                sudo apt-get install -y docker
                ;;
            "centos"|"rhel"|"fedora"|"opencloudos")
                echo "******************在CentOS/RHEL/Fedora/OpenCloudOS上安装Docker******************"
                sudo yum install -y docker
                ;;
            *)
                echo "******************不支持的Linux发行版: $ID******************"
                exit  1
                ;;
        esac
    else
        echo "无法确定操作系统类型"
        exit  1
    fi
    # 检查Docker是否安装成功
    if command -v docker &> /dev/null; then
        echo "******************Docker安装成功******************"
    else
        echo "******************Docker安装失败******************"
        exit  1
    fi
}

# 初始化docker
init_docker(){
        # 安装依赖
        echo "******************更新系统并安装必要的依赖******************"
        if [ -f /etc/lsb-release ]; then
            # 对于基于Debian的系统
            apt-get update && apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            software-properties-common
        elif [ -f /etc/redhat-release ]; then
            # 对于基于RHEL的系统
            yum update && yum install -y \
            yum-utils \
            device-mapper-persistent-data \
            lvm2
        else
            echo "*****************不一定支持但在强制安装Docker*****************" 
        fi
        # 安装Docker
        echo "******************正在安装Docker...******************"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        if [ $? -eq 0 ]; then
            echo "******************Docker安装成功******************"
        else
            echo "******************Docker安装失败（尝试其他方式安装docker）******************" 1>&2
            install_docker
        fi
    # 启动并使Docker开机自启
    systemctl start docker
    systemctl enable docker
    # 拉取指定的Docker镜像
    docker pull docker.io/nezha123/titan-edge:1.0
    echo "******************Docker安装脚本执行完毕******************"
}




# 检查是否使用NFS 
check_use_nfs(){
	# 根据nfsurl参数设置基础目录
	if [ -n "$nfsurl" ] || [ "$already_install_NFS" -eq 1 ]; then
	    random_str=$(generate_random_string)
	    folder="/mnt/titan/$random_str"
	    install_nfs_client
		mount_nfs
	else
	    folder="/mnt"
	fi
}

# 主机安装函数
titan_host_install(){
    wget -c https://zeenyun-temp.oss-cn-shanghai.aliyuncs.com/titan_v0.1.13.tar.gz  -O - | sudo tar -xz -C /usr/local/bin --strip-components=1 
    nohup titan-edge daemon start --init --url https://test-locator.titannet.io:5000/rpc/v0 > edge.log 2>&1 &
    sleep 10 
    # 查找titan-edge daemon进程的PID
	pid=$(ps aux | grep "titan-edge daemon start" | grep -v grep | awk '{print $2}')
	# 如果找到了PID，尝试杀掉进程
	if [ ! -z "$pid" ]; then
		   echo "杀掉进程ID为 $pid 的进程."
		   kill $pid
		    # 检查进程是否被杀掉，如果没有，使用kill -9
		   if kill -0 $pid > /dev/null 2>&1; then
		       echo "进程 $pid 没有响应，已使用kill -9."
		       kill -9 $pid
		   fi
	else
		    echo "没有找到 titan-edge daemon 进程."
		fi
    nohup titan-edge daemon start --init> edge.log 2>&1 &
    echo "................等30秒进行绑定中"
    sleep 30 
    titan-edge bind --hash=$code  https://api-test1.container1.titannet.io/api/v2/device/binding 
    echo "**********************主机绑定完成******************8"
    setup_host_daemon_job
}
###################################函数区域结束#################################

# 检测是否为root用户
if [ "$(id -u)" != "0" ]; then
   echo "该脚本需要以root权限运行" 1>&2
   exit 1
fi


# 处理命令行参数
while [ "$#" -gt 0 ]; do
    case "$1" in
        --type=*) type="${1#*=}" ;;
        --code=*) code="${1#*=}" ;;
        --already_install_NFS=*) already_install_NFS="${1#*=}" ;;
        --nfsurl=*) nfsurl="${1#*=}"  ;; # 如果提供了nfsurl，则容器数量改为5
        --containers=*) containers="${1#*=}" ;;
        -h|--help) show_help; exit 0 ;;
        *) echo "未知参数: $1" ; show_help; exit 1 ;;
    esac
    shift
done

init_docker
check_use_nfs
case $type in
    1)
        echo "******************您选择了安装5个容器***********************"
        containers=5 
        sleep 2
        ;;
    2)
        echo "******************您选择了主机安装+4个容器*******************"
        sleep 2
        echo ""
        echo "******************正在准备安装主机任务************************"
        titan_host_install
        echo "******************主机安装完成*****************************"
        ;;

    *)
        echo "无效的输入，请输入1或2。"
        exit 1
        ;;
esac

echo "******************创建主机docker映射目录中******************"
create_storage_directories
echo "******************创建主机docker映射目录完成******************"
sleep 5
echo "******************正在准备运行容器******************"
run_containers
echo "******************容器运行完成******************"
sleep 5
echo "******************容器身份绑定中******************"
setup_and_bind
echo "******************容器身份绑定完成******************"
sleep 5
echo "******************正在准备运行容器守护进程******************"
setup_cron_job
echo "******************容器守护进程运行完成******************"
sleep 5
echo "******************所有任务安装完成******************"






