#!/bin/sh


WORK_PATH=~/works/                      # 工作目录
BUILD_PATH="${WORK_PATH}git/halo/"      # halo打包目录
WWW_PATH="/www/wwwroot/"                # www目录
HALO_PATH="${WWW_PATH}halo/"            # halo部署目录
HALO_CONFIG="${HALO_PATH}resources/application.yaml"           
NGINX_PATH="/usr/local/nginx/"          # nginx安装目录
NGINX_VERSION="1.14.0"                  # nginx版本


####### 颜色代码 ########
RED="31m"      # Error message
GREEN="32m"    # Success message
YELLOW="33m"   # Warning message
BLUE="36m"     # Info message


colorEcho(){
    COLOR=$1
    echo -e "\033[${COLOR}${@:2}\033[0m"
}



useage(){
    colorEcho ${YELLOW} "使用方法:sh halo-cli.sh [1(安装Halo) | 2(更新Halo) | 3(安装nginx)]"
    exit 1
}


installHalo(){
    ### 安装halo ###
    colorEcho ${BLUE} "正在使用yum安装maven,openjdk1.8,git"
    yum install -y -q git maven java-1.8.0-openjdk  java-1.8.0-openjdk-devel
    
    echo -e "----------------------------------------------------"
    colorEcho ${GREEN} "JDK版本为: `java -version | head -1`"
    colorEcho ${GREEN} "Maven版本为: `mvn --version | head -1`"
    echo -e "----------------------------------------------------"
    
    if [[ -d ${BUILD_PATH} ]]; then
        rm -rf ${BUILD_PATH}
    fi
    echo -e "----------------------------------------------------"
    colorEcho ${BLUE} "克隆Halo中..."
    echo -e "----------------------------------------------------"
    git clone https://gitee.com/babyrui/halo ${BUILD_PATH}

    cd ${BUILD_PATH}
    mvn clean package -Pprod 
    STATUS=$?
    if [[ $STATUS == 0 ]]; then
        echo -e "----------------------------------------------------"
        colorEcho ${GREEN} "Halo最新版打包成功"
        echo -e "----------------------------------------------------"
        mkdir -p ${HALO_PATH}
        cp -R target/dist/halo ${WWW_PATH}
        touch /etc/systemd/system/halo.service
    cat > /etc/systemd/system/halo.service << EOF
[Unit]
Description=halo
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/bin/java -server -Xms256m -Xmx512m -jar /www/wwwroot/halo/halo-latest.jar
ExecStop=/bin/kill -s QUIT $MAINPID
Restart=always
StandOutput=syslog

StandError=inherit

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    else
        echo -e "----------------------------------------------------"
        colorEcho ${RED} "打包失败"
        echo -e "----------------------------------------------------"
        exit 1
    fi

    if [[ -d ${HALO_PATH} ]]; then
        configHalo
        echo -e "----------------------------------------------------"
        colorEcho ${GREEN} "Halo安装成功"
        colorEcho ${GREEN} "使用systemctl start halo启动"
        colorEcho ${GREEN} "使用systemctl enable halo将Halo加入开机启动"
        echo -e "----------------------------------------------------"
    else 
        echo -e "----------------------------------------------------"
        colorEcho ${RED} "貌似安装出错了,请手动检测安装目录${HALO_PATH}是否存在Halo"
        echo -e "----------------------------------------------------"
        exit 1
    fi
}

updateHalo(){
    if [[ -d ${HALO_PATH} ]]; then 
        cd ${BUILD_PATH}
        git pull
        mvn clean package -Pprod
        STATUS=$?    
        if [[ $STATUS == 0 ]]; then
            echo -e "----------------------------------------------------"
            colorEcho ${GREEN} "Halo最新版打包成功"
            cp ${HALO_PATH}resources/application.yaml ${HALO_PATH}resources/application.yaml.bak
            cp -R target/dist/halo ${WWW_PATH}
            cp ${HALO_PATH}resources/application.yaml.bak ${HALO_PATH}resources/application.yaml
            colorEcho ${GREEN} "使用systemctl restart halo重启"
            echo -e "----------------------------------------------------"
        else
            echo -e "----------------------------------------------------"
            colorEcho ${RED} "打包失败"
            echo -e "----------------------------------------------------"
            exit 1
        fi
    else
        echo -e "----------------------------------------------------"
        colorEcho ${RED} "Sorry,貌似还未安装halo哦,请先执行安装"
        echo -e "----------------------------------------------------"
        exit 1
    fi
}

configHalo() {
    echo -e "\n"
    echo -e "----------------------------------------------------"
    colorEcho ${BLUE} '接下来将进行Halo的一些配置'
    colorEcho ${BLUE}  "Halo支持两种数据库类型："
    colorEcho ${GREEN} '1):h2'
    colorEcho ${GREEN} '2):mysql/mariadb'
    echo -e "----------------------------------------------------"
    read -p '请选择数据库编号:' database
    if [[ $database == "2" ]]; then 
        colorEcho ${YELLOW} "选择mysql/mariadb需要自行安装mysql/mariadb"
        colorEcho ${YELLOW} "并建立名为halodb的数据库"
    fi
    
    colorEcho ${GREEN} "数据库类型为：${database}"
    read -p '数据库的用户名：' username
    colorEcho ${GREEN} "数据库用户名为：${username}"
    read -p '数据库的密码：' -s password
    echo -e "\n"
    read -p 'Halo要使用的端口(默认8090)：' port
    colorEcho ${GREEN} "Halo的端口为：${port}"


    case $database in
        1)
            sed -i '2s/8090/'$port'/' ${HALO_CONFIG}
            sed -i "16s/admin/${username}/" ${HALO_CONFIG}
            sed -i "17s/123456/${password}/" ${HALO_CONFIG}
        ;;
        2|3)
            echo          
            sed -i '14,17s/^[^#]/#&/' ${HALO_CONFIG}
            sed -i '20,23s/^#\(\)/\1/' ${HALO_CONFIG}
            sed -i '2s/8090/'$port'/' ${HALO_CONFIG}
            sed -i "22s/root/${username}/" ${HALO_CONFIG}
            sed -i "23s/123456/${password}/" ${HALO_CONFIG}
        ;;
        *) 
            echo -e "----------------------------------------------------"
            colorEcho ${RED} '未知类型数据库,请重新配置'
            echo -e "----------------------------------------------------"
            configHalo
        ;;
    esac
}
    

installNginx(){
    ### 编译安装nginx ###

    colorEcho ${BLUE} "正在安装nginx所需依赖"
    yum install -y -q gcc gcc-c++ autoconf automake git wget 
    yum install -y -q zlib zlib-devel openssl openssl-devel pcre pcre-devel

    groupadd -r nginx      # 创建nginx用户组
    useradd -s /sbin/nologin -g nginx -r nginx    # 创建nginx用户

    cd ${WORK_PATH}
     colorEcho ${BLUE} "正在下载nginx源码包"
    wget -O nginx.tar.gz -q http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
    tar zxf nginx.tar.gz 

    colorEcho ${BLUE} "正在克隆echo-nginx-module"
    git clone https://github.com/openresty/echo-nginx-module.git         # 克隆echo-nginx-module


    cd nginx-${NGINX_VERSION}

    ./configure --prefix=${NGINX_PATH} \
     --user=nginx \
     --group=nginx \
     --with-http_ssl_module \
     --with-http_v2_module \
     --add-module=../echo-nginx-module
    
    process=`grep -c ^processor /proc/cpuinfo`
    colorEcho ${BLUE} "检测到${process}个CPU线程,将开始编译"
    make -j${process}

    make install 

    if [[ -d ${NGINX_PATH} ]]; then 
        ln -sf ${NGINX_PATH}sbin/nginx /usr/sbin/nginx
        colorEcho ${GREEN} "nginx安装成功"
    touch /etc/systemd/system/nginx.service
    cat > /etc/systemd/system/nginx.service <<EOF 
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/usr/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    colorEcho ${GREEN} "请运行systemctl start nginx 或 nginx启动nginx"
    else
        colorEcho ${RED} "nginx安装失败"
    fi

}

if [[ $# == 1 ]]; then
    case $1 in 
        1)
    installHalo
    ;;
        2)
    updateHalo
    ;;
        
        3)
    installNginx
    ;;
        *)
    useage
    ;;
esac
else 
    useage
fi

