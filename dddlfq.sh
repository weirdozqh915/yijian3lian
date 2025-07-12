#!/bin/bash

# 默认值设置
DEFAULT_USERNAME="dddlfq"
DEFAULT_PASSWORD="dddlfq"
DEFAULT_QB_PORT=18080
DEFAULT_FB_PORT=18082

install_qbittorrent() {
    echo "开始安装 qBittorrent..."
    
    # 安装 QB
    cd /root
    bash <(wget -qO- https://raw.githubusercontent.com/SAGIRIxr/Dedicated-Seedbox/main/Install.sh) \
        -u ${USERNAME} \
        -p ${PASSWORD} \
        -c 4096 \
        -q 4.3.8 \
        -l v1.2.14 \
        -x

    # 停止服务以修改配置
    systemctl stop qbittorrent-nox@${USERNAME}
    sleep 5

    # 修改 QB 配置
    QB_CONFIG="${HOME_DIR}/.config/qBittorrent/qBittorrent.conf"
    
    # 检查配置文件是否存在
    if [ ! -f "${QB_CONFIG}" ]; then
        echo "等待配置文件生成..."
        sleep 10
    fi

    # 修改配置
    sed -i 's|WebUI\\\Port=.*|WebUI\\\Port='"${QB_PORT}"'|' "${QB_CONFIG}"
    sed -i 's|Connection\\\PortRangeMin=.*|Connection\\\PortRangeMin=45000|' "${QB_CONFIG}"
    sed -i '/\[Preferences\]/a General\\\Locale=zh' "${QB_CONFIG}"
    sed -i '/\[Preferences\]/a Downloads\\\PreAllocation=false' "${QB_CONFIG}"
    sed -i '/\[Preferences\]/a WebUI\\\CSRFProtection=false' "${QB_CONFIG}"

    # 启动服务
    systemctl start qbittorrent-nox@${USERNAME}
}

install_filebrowser() {
    echo "开始安装 FileBrowser..."
    
    docker run -d \
        --name filebrowser \
        --restart=unless-stopped \
        -e PUID=1000 \
        -e PGID=1000 \
        -e WEB_PORT=${FB_PORT} \
        -e FB_AUTH_SERVER_ADDR=127.0.0.1 \
        -p ${FB_PORT}:${FB_PORT} \
        -v ${HOME_DIR}/fb/config:/config \
        -v /home/downloads:/myfiles \
        --mount type=tmpfs,destination=/tmp \
        80x86/filebrowser
}

install_clouddrive2() {
    echo "开始安装 CloudDrive2..."
    
    # 创建必要的目录
    mkdir -p /123
    mkdir -p /cd2
    
    docker run -d \
        --name clouddrive2 \
        --restart=unless-stopped \
        -e TZ=Asia/Shanghai \
        -e CLOUDDRIVE_HOME=/Config \
        -v /123:/CloudNAS:shared \
        -v /cd2:/Config \
        --device=/dev/fuse:/dev/fuse \
        --pid=host \
        --privileged \
        --network=host \
        cloudnas/clouddrive2
}

echo "欢迎使用安装脚本"
echo "将自动安装以下组件："
echo "- qBittorrent (端口: ${DEFAULT_QB_PORT})"
echo "- FileBrowser (端口: ${DEFAULT_FB_PORT})"
echo "- CloudDrive2"

# 使用默认配置
USERNAME=${DEFAULT_USERNAME}
PASSWORD=${DEFAULT_PASSWORD}
QB_PORT=${DEFAULT_QB_PORT}
FB_PORT=${DEFAULT_FB_PORT}

# 确认安装
echo -n "确认开始安装？[Y/n] "
read confirm
if [[ ${confirm,,} == "n" ]]; then
    echo "安装已取消"
    exit 1
fi

# 系统更新和基础软件安装
echo "正在更新系统并安装基础软件..."
apt update -y && apt upgrade -y
apt install curl wget unzip htop vnstat -y

# 安装 Docker
echo "安装 Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 设置时区
timedatectl set-timezone Asia/Shanghai

# 创建用户目录
HOME_DIR="/home/${USERNAME}"
mkdir -p ${HOME_DIR}

# 安装所有组件
install_qbittorrent
install_filebrowser
install_clouddrive2

# 配置 qBittorrent
echo "等待 qBittorrent WebUI 启动..."
sleep 10

# 通过 API 修改 qBittorrent 配置
curl -X POST "http://localhost:${QB_PORT}/api/v2/auth/login" \
    -d "username=${USERNAME}&password=${PASSWORD}"

# 保存 cookie 以便后续请求使用
COOKIE=$(curl -s -i -X POST "http://localhost:${QB_PORT}/api/v2/auth/login" \
    -d "username=${USERNAME}&password=${PASSWORD}" | grep -i "set-cookie" | cut -d' ' -f2)

# 修改磁盘缓存设置为 -1
curl -X POST "http://localhost:${QB_PORT}/api/v2/app/setPreferences" \
    -b "$COOKIE" \
    -d 'json={"disk_cache":-1}'

echo -e "\nsystemctl enable qbittorrent-nox@${USERNAME} && reboot" >> /root/BBRx.sh

echo "安装完成！系统将在1分钟后重启..."
shutdown -r +1 
