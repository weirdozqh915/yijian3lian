#!/bin/bash

# 默认值设置
DEFAULT_USERNAME="chaoaman"
DEFAULT_PASSWORD="chaoaman888"
DEFAULT_QB_PORT=18888
DEFAULT_FB_PORT=28888

# 定义安装函数
install_vertex() {
    echo "开始安装 vertex..."
    
    # 下载并解压项目文件
    rm -rf ${HOME_DIR}
    mkdir -p ${HOME_DIR}
    
    case "${project_choice}" in
        "2")
            wget https://github.com/su1xiao/sgvt/archive/refs/heads/main.zip -O /tmp/project.zip
            unzip -o /tmp/project.zip -d /tmp
            cp -rf /tmp/sgvt-main/* ${HOME_DIR}/
            rm -rf /tmp/sgvt-main /tmp/project.zip
            ;;
        *)  
            wget https://github.com/su1xiao/seedbox/archive/refs/heads/main.zip -O /tmp/project.zip
            unzip -o /tmp/project.zip -d /tmp
            cp -rf /tmp/seedbox-main/* ${HOME_DIR}/
            rm -rf /tmp/seedbox-main /tmp/project.zip
            ;;
    esac

    # 启动 vertex 容器
    docker run -d \
        --name vertex \
        --restart=unless-stopped \
        --network host \
        -v ${HOME_DIR}/vertex:/vertex \
        -e TZ=Asia/Shanghai \
        lswl/vertex:stable
}

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

# 显示主菜单
cat << 'EOF'








 .oOOOo.  o      O    Oo     .oOOOo.           Oo          Oo      oO    Oo    o.     O 
.O     o  O      o   o  O   .O     o.         o  O         O O    o o   o  O   Oo     o 
o         o      O  O    o  O       o        O    o        o  o  O  O  O    o  O O    O 
o         OoOooOOo oOooOoOo o       O       oOooOoOo       O   Oo   O oOooOoOo O  o   o 
o         o      O o      O O       o       o      O       O        o o      O O   o  O 
O         O      o O      o o       O       O      o       o        O O      o o    O O 
`o     .o o      o o      O `o     O'       o      O       o        O o      O o     Oo 
 `OoooO'  o      O O.     O  `OoooO'        O.     O       O        o O.     O O     `o 
EOF
echo "欢迎使用安装脚本"
echo "请选择安装方式："
echo "1. 我啥都偷"
echo "2. 我看看我想偷哪个"
echo "3. 偷个vt算了"
echo "4. 偷个qb算了"
echo -n "今天偷点啥 [1-4]: "
read install_type

case "${install_type}" in
    "1")
        # 一键三连模式
        USERNAME=${DEFAULT_USERNAME}
        PASSWORD=${DEFAULT_PASSWORD}
        QB_PORT=${DEFAULT_QB_PORT}
        FB_PORT=${DEFAULT_FB_PORT}
        INSTALL_ALL=true
        echo "将使用默认配置进行安装..."
        ;;
        
    "2")
        # 自定义安装模式
        echo -e "\n请输入设置信息:"
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
        INSTALL_ALL=true
        ;;
        
    "3")
        # 仅安装 VT
        USERNAME=${DEFAULT_USERNAME}
        echo -e "\n请选择 VT 版本："
        echo "1. 云飞版 (默认)"
        echo "2. 时光版"
        echo -n "请输入选项 [1/2]: "
        read project_choice
        echo "仅安装 vertex..."
        INSTALL_VT_ONLY=true
        ;;
        
    "4")
        # 仅安装 QB
        echo -n "用户名 [${DEFAULT_USERNAME}]: "
        read input_username
        USERNAME=${input_username:-$DEFAULT_USERNAME}

        echo -n "密码 [${DEFAULT_PASSWORD}]: "
        read input_password
        PASSWORD=${input_password:-$DEFAULT_PASSWORD}

        echo -n "qBittorrent 端口 [${DEFAULT_QB_PORT}]: "
        read input_qb_port
        QB_PORT=${input_qb_port:-$DEFAULT_QB_PORT}
        INSTALL_QB_ONLY=true
        ;;
        
    *)
        echo "无效的选项，退出安装"
        exit 1
        ;;
esac

# 如果需要安装 VT 但还没选择版本，询问 VT 版本
if [ "$INSTALL_ALL" = true ] && [ -z "$project_choice" ]; then
    echo -e "\n请选择 VT 版本："
    echo "1. 云飞版 (默认)"
    echo "2. 时光版"
    echo -n "请输入选项 [1/2]: "
    read project_choice
fi

# 显示安装信息
echo -e "\n即将进行如下安装："
case "${install_type}" in
    "1") echo "一键三连 - 使用默认配置" ;;
    "2") echo "自定义安装 - 全部组件" ;;
    "3") echo "仅安装 VT" ;;
    "4") echo "仅安装 QB" ;;
esac

# 确认安装
echo -n "确认继续安装？[Y/n] "
read confirm
if [[ ${confirm,,} == "n" ]]; then
    echo "安装已取消"
    exit 1
fi

# 根据安装类型执行不同的安装步骤
if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_VT_ONLY" = true ] || [ "$INSTALL_QB_ONLY" = true ]; then
    # 系统更新和基础软件安装
    echo "正在更新系统并安装基础软件..."
    apt update -y && apt upgrade -y
    apt install curl wget unzip htop vnstat -y

    # 安装 Docker（如果需要）
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_VT_ONLY" = true ]; then
        echo "安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
    fi

    # 设置时区
    timedatectl set-timezone Asia/Shanghai

    # 创建用户目录
    HOME_DIR="/home/${USERNAME}"
    mkdir -p ${HOME_DIR}

    # 根据安装类型执行不同的安装步骤
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_VT_ONLY" = true ]; then
        install_vertex
    fi

    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_QB_ONLY" = true ]; then
        install_qbittorrent
    fi

    if [ "$INSTALL_ALL" = true ]; then
        install_filebrowser
    fi

    # 如果安装了 QB，添加到 BBRx.sh
    if [ "$INSTALL_ALL" = true ] || [ "$INSTALL_QB_ONLY" = true ]; then

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
    fi
fi

echo "安装完成！系统将在1分钟后重启..."
shutdown -r +1 
