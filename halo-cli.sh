#!/bin/bash

export LANG=zh_CN.UTF-8

WORK_PATH=~/works/                      # 工作目录
BUILD_PATH="${WORK_PATH}git/halo/"      # halo打包目录
WWW_PATH="/www/wwwroot/"                # www目录
HALO_PATH="${WWW_PATH}halo/"            # halo部署目录
HALO_CONFIG="${HALO_PATH}resources/application.yaml"           

database=1
port=8090


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
    colorEcho ${YELLOW} "使用方法:"
    colorEcho ${YELLOW} "安装halo: bash halo-cli.sh -i 或 bash halo-cli.sh --install"
    colorEcho ${YELLOW} "更新halo: bash halo-cli.sh -u 或 bash halo-cli.sh --update"
    exit 1
}

installGit(){
    if [[ -n `command -v apt-get` ]];then
        CMD_INSTALL="apt-get -y install"
        CMD_UPDATE="apt-get update"
    elif [[ -n `command -v yum` ]]; then
        CMD_INSTALL="yum -y install"
        CMD_UPDATE="yum makecache"
    else
        return 1
    fi

    ${CMD_UPDATE} && ${CMD_INSTALL} git
}

checkJavaEnv(){

    if [[ -n `command -v java` && -n `command -v mvn` ]];then
        echo -e "----------------------------------------------------"
        colorEcho ${BLUE} "发现系统中存在java和maven"
        colorEcho ${GREEN} "JDK版本为: `java -version`"
        colorEcho ${GREEN} "Maven版本为: `mvn --version`"
        echo -e "----------------------------------------------------"
        hasJavaEnv=true
    else
        hasJavaEnv=false
    fi

}

configJavaEnv(){

    echo -e "----------------------------------------------------"
    colorEcho ${BLUE} "将通过下载官方二进制包的形式安装OpenJDK和Maven"
    echo -e "----------------------------------------------------"

    if [[ ! -d $WORK_PATH ]];then
        mkdir ${WORK_PATH}
    fi

    wget -O ${WORK_PATH}jdk1.8.0_192.tar.gz https://download.java.net/java/jdk8u192/archive/b04/binaries/jdk-8u192-ea-bin-b04-linux-x64-01_aug_2018.tar.gz
    wget -O ${WORK_PATH}maven-3.6.0-bin.tar.gz https://mirrors.tuna.tsinghua.edu.cn/apache/maven/maven-3/3.6.0/binaries/apache-maven-3.6.0-bin.tar.gz

    colorEcho ${BLUE} "解压中------"
    tar zxf ${WORK_PATH}jdk1.8.0_192.tar.gz -C /usr/lib
    tar zxf ${WORK_PATH}maven-3.6.0-bin.tar.gz -C /usr/lib

    echo 'export JAVA_HOME=/usr/lib/jdk1.8.0_192' | tee /etc/profile.d/jdk8.sh
    echo 'export JRE_HOME=${JAVA_HOME}/jre' | tee -a /etc/profile.d/jdk8.sh
    echo 'export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib' | tee -a /etc/profile.d/jdk8.sh
    echo 'export PATH=${JAVA_HOME}/bin:$PATH' | tee -a /etc/profile.d/jdk8.sh

    echo 'export MAVEN_HOME=/usr/lib/apache-maven-3.6.0' | tee  /etc/profile.d/maven.sh
    echo 'export PATH=${MAVEN_HOME}/bin:$PATH' | tee -a /etc/profile.d/maven.sh

    source /etc/profile

    echo -e "----------------------------------------------------"
    colorEcho ${GREEN} "JDK版本为: `java -version`"
    colorEcho ${GREEN} "Maven版本为: `mvn --version`"
    echo -e "----------------------------------------------------"

}

installHalo(){
    ### 安装halo ###

    installGit
    checkJavaEnv 

    if [[ ! hasJavaEnv == false ]];then
        configJavaEnv
    fi

    if [[ ! -d $WORK_PATH ]];then
        mkdir ${WORK_PATH}
    fi
    
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

        ### 检测系统是否支持systemd
        if [[ -n `command -v systemctl` ]];then
            touch /etc/systemd/system/halo.service
            cat > /etc/systemd/system/halo.service << EOF
[Unit]
Description=halo
After=network.target
Wants=network.target

[Service]
Type=simple
ExecStart=/usr/lib/jdk1.8.0_192/bin/java -server -Xms256m -Xmx512m -jar /www/wwwroot/halo/halo-latest.jar
ExecStop=/bin/kill -s QUIT $MAINPID
Restart=always
StandOutput=syslog

StandError=inherit

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload

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
        
        else

            if [[ -d ${HALO_PATH} ]]; then
                configHalo
                echo -e "----------------------------------------------------"
                colorEcho ${GREEN} "Halo安装成功"
                colorEcho ${GREEN} "由于未找到systemctl命令所以判定为不支持systemd"
                colorEcho ${GREEN} "使用\"sh /www/wwwroot/halo/bin/halo.sh start\"运行halo"
                echo -e "----------------------------------------------------"
            else 
                echo -e "----------------------------------------------------"
                colorEcho ${RED} "貌似安装出错了,请手动检测安装目录${HALO_PATH}是否存在Halo"
                echo -e "----------------------------------------------------"
                exit 1
            fi

        fi

    else
        echo -e "----------------------------------------------------"
        colorEcho ${RED} "打包失败"
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
            colorEcho ${GREEN} "使用手动重启halo"
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
    colorEcho ${BLUE}  "Halo支持两种数据库类型(默认h2,无特殊需求默认即可)："
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
            sed -i '2s/8090/'${port}'/' ${HALO_CONFIG}
            sed -i "16s/admin/${username}/" ${HALO_CONFIG}
            sed -i "17s/123456/${password}/" ${HALO_CONFIG}
        ;;
        2|3)
            echo          
            sed -i '14,17s/^[^#]/#&/' ${HALO_CONFIG}
            sed -i '20,23s/^#\(\)/\1/' ${HALO_CONFIG}
            sed -i '2s/8090/'${port}'/' ${HALO_CONFIG}
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
    

if [[ $# == 1 ]]; then
    case $1 in 
        -i|--install)
            installHalo
    ;;
        -u|--update)
            updateHalo
    ;;
        *)
            useage
    ;;
    esac
else 
    useage
fi

