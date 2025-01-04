#!/bin/bash

# 默认值设置
DEFAULT_USERNAME="su1xiao"
DEFAULT_PASSWORD="bDEN08FIEhb0wZ"
DEFAULT_QB_PORT=18080
DEFAULT_FB_PORT=18082



# 用户输入处理
echo -e "\n请输入设置信息 (直接回车将使用默认值)"
echo -n "用户名 [${DEFAULT_USERNAME}]: "
read input_username
USERNAME=${input_username:-$DEFAULT_USERNAME}

echo -n "密码 [${DEFAULT_PASSWORD}]: "
read input_password
PASSWORD=${input_password:-$DEFAULT_PASSWORD}

echo -n "qBittorrent 端口 [${DEFAULT_QB_PORT}]: "
read input_qb_port
QB_PORT=${input_qb_port:-$DEFAULT_QB_PORT}

echo -n "FileBrowser 端口 [${DEFAULT_FB_PORT}]: "
read input_fb_port
FB_PORT=${input_fb_port:-$DEFAULT_FB_PORT}

# 项目选择
echo "请选择要安装的VT版本："
echo "1. 云飞版 (默认)"
echo "2. 时光版"
echo -n "请输入选项 [1/2]: "
read project_choice

# 确认设置
echo -e "\n您的设置如下："
echo "VT版本: $([ "$project_choice" = "2" ] && echo "时光版" || echo "云飞版")"
echo "用户名: ${USERNAME}"
echo "密码: ${PASSWORD}"
echo "qBittorrent 端口: ${QB_PORT}"
echo "FileBrowser 端口: ${FB_PORT}"
echo -n "确认继续安装？[Y/n] "
read confirm
if [[ ${confirm,,} == "n" ]]; then
    echo "安装已取消"
    exit 1
fi

# 设置主目录
HOME_DIR="/home/${USERNAME}"

# 系统更新和基础软件安装
echo "正在更新系统并安装基础软件..."
apt update -y && apt upgrade -y
apt install curl wget unzip htop vnstat -y

# 设置时区
echo "设置系统时区..."
timedatectl set-timezone Asia/Shanghai

# 安装 Docker
echo "安装 Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 下载并解压项目文件
echo "下载并解压项目文件..."

# 确保目录为空或不存在
rm -rf ${HOME_DIR}
mkdir -p ${HOME_DIR}

case "${project_choice}" in
    "2")
        wget https://github.com/su1xiao/sgvt/archive/refs/heads/main.zip -O /tmp/project.zip
        unzip -o /tmp/project.zip -d /tmp
        cp -rf /tmp/sgvt-main/* ${HOME_DIR}/
        rm -rf /tmp/sgvt-main /tmp/project.zip
        ;;
    *)  # 默认选项1或者无效输入
        wget https://github.com/su1xiao/seedbox/archive/refs/heads/main.zip -O /tmp/project.zip
        unzip -o /tmp/project.zip -d /tmp
        cp -rf /tmp/seedbox-main/* ${HOME_DIR}/
        rm -rf /tmp/seedbox-main /tmp/project.zip
        ;;
esac

# 清理临时文件
echo "清理临时文件..."
rm -rf /home/get-docker.sh /home/seedbox-main ${HOME_DIR}.zip

# 安装 qBittorrent
echo "安装 qBittorrent..."
cd /root
bash <(wget -qO- https://raw.githubusercontent.com/SAGIRIxr/Dedicated-Seedbox/main/Install.sh) \
    -u ${USERNAME} \
    -p ${PASSWORD} \
    -c 4096 \
    -q 4.3.8 \
    -l v1.2.14 \
    -x

# 配置 qBittorrent
echo "配置 qBittorrent..."
systemctl stop qbittorrent-nox@${USERNAME}
systemctl disable qbittorrent-nox@${USERNAME}

# 调整文件系统
tune2fs -m 1 $(df -h / | awk 'NR==2 {print $1}')

# 修改 qBittorrent 配置
QB_CONFIG="${HOME_DIR}/.config/qBittorrent/qBittorrent.conf"
sed -i "s/WebUI\\Port=[0-9]*/WebUI\\Port=${QB_PORT}/" ${QB_CONFIG}
sed -i 's/Connection\\PortRangeMin=[0-9]*/Connection\\PortRangeMin=45000/' ${QB_CONFIG}
sed -i '/\[Preferences\]/a General\\Locale=zh' ${QB_CONFIG}
sed -i '/\[Preferences\]/a Downloads\\PreAllocation=false' ${QB_CONFIG}
sed -i '/\[Preferences\]/a WebUI\\CSRFProtection=false' ${QB_CONFIG}

# 启动 Docker 容器
echo "启动 Docker 容器..."

# 启动 vertex 容器
docker run -d \
    --name vertex \
    --restart=unless-stopped \
    --network host \
    -v ${HOME_DIR}/vertex:/vertex \
    -e TZ=Asia/Shanghai \
    lswl/vertex:stable

# 启动 filebrowser 容器
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

# 启动 unpacking 容器
docker run -d \
    --name=unpacking \
    --net=host \
    --restart=unless-stopped \
    -v ${HOME_DIR}/cb:/home/user \
    -e username=${USERNAME} \
    -e password=${USERNAME}233 \
    -e rate=0.6 \
    -e time=5 \
    -e url=http://127.0.0.1:${QB_PORT} \
    ppw111/ptchange:v0.3

# 重启所有容器
docker restart $(docker ps -q)

# 设置 qBittorrent 开机自启动
systemctl enable qbittorrent-nox@${USERNAME}

# 等待 qBittorrent WebUI 启动
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

# 添加重启命令到 BBRx.sh
echo -e "\nsystemctl enable qbittorrent-nox@${USERNAME} && reboot" >> /root/BBRx.sh

# 1分钟后重启系统
shutdown -r +1
echo "安装完成！系统将在1分钟后重启..."
