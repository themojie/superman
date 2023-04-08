#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误：${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
else
  arch="amd64"
  echo -e "${red}检测架构失败，使用默认架构: ${arch}${plain}"
fi

echo "架构: ${arch}"

if [ "$(getconf WORD_BIT)" != '32' ] && [ "$(getconf LONG_BIT)" != '64' ] ; then
    echo "本软件不支持 32 位系统(x86)，请使用 64 位系统(x86_64)，如果检测有误，请联系作者"
    exit 2
fi

#os_version=""
#
## os version
#if [[ -f /etc/os-release ]]; then
#    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
#fi
#if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
#    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
#fi
#
#if [[ x"${release}" == x"centos" ]]; then
#    if [[ ${os_version} -le 6 ]]; then
#        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
#    fi
#elif [[ x"${release}" == x"ubuntu" ]]; then
#    if [[ ${os_version} -lt 16 ]]; then
#        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
#    fi
#elif [[ x"${release}" == x"debian" ]]; then
#    if [[ ${os_version} -lt 8 ]]; then
#        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
#    fi
#fi

function is_cmd_exist() {
    local cmd="$1"
    if [ -z "$cmd" ]; then
        return 1
    fi

    which "$cmd" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        return 0
    fi

	  return 2
}

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install epel-release -y
        yum install wget curl tar crontabs socat tzdata -y
    else
        apt install wget curl tar cron socat tzdata -y
    fi
}

# 0: running, 1: not running, 2: not installed
check_status() {
    if [[ ! -f /etc/systemd/system/superman.service ]]; then
        return 2
    fi
    temp=$(systemctl status superman | grep Active | awk '{print $3}' | cut -d "(" -f2 | cut -d ")" -f1)
    if [[ x"${temp}" == x"running" ]]; then
        return 0
    else
        return 1
    fi
}

install_superman() {
    if [[ -e /usr/local/superman/ ]]; then
        rm /usr/local/superman/ -rf
    fi

    rm superman/ -rf
    tar zxvf superman-linux-${arch}.tar.gz
    mv superman /usr/local/
    cd /usr/local/superman/
    chmod +x superman superman.sh
    mkdir /etc/superman/ -p
    rm /etc/systemd/system/superman.service -f
    cp -f superman.service /etc/systemd/system/
    cp -f superman.sh /usr/local/bin/superman
    systemctl daemon-reload
    systemctl stop superman
    systemctl enable superman
    echo -e "${green}superman 安装完成，已设置开机自启${plain}"
    if [[ ! -f /etc/superman/superman.conf ]]; then
        cp superman.conf /etc/superman/
        echo -e ""
        echo -e "全新安装，请先配置必要的内容"
    else
        systemctl start superman
        sleep 2
        check_status
        echo -e ""
        if [[ $? == 0 ]]; then
            echo -e "${green}superman 重启成功${plain}"
        else
            echo -e "${red}superman 可能启动失败，请稍后使用 superman log 查看日志信息${plain}"
        fi
    fi

    echo -e ""
    echo "superman 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "superman                    - 显示管理菜单 (功能更多)"
    echo "superman start              - 启动 superman"
    echo "superman stop               - 停止 superman"
    echo "superman restart            - 重启 superman"
    echo "superman status             - 查看 superman 状态"
    echo "superman enable             - 设置 superman 开机自启"
    echo "superman disable            - 取消 superman 开机自启"
    echo "superman log                - 查看 superman 日志"
    echo "superman uninstall          - 卸载 superman"
    echo "superman version            - 查看 superman 版本"
    echo "------------------------------------------"
}

is_cmd_exist "systemctl"
if [[ $? != 0 ]]; then
    echo "systemctl 命令不存在，请使用较新版本的系统，例如 Ubuntu 18+、Debian 9+"
    exit 1
fi

echo -e "${green}开始安装${plain}"
install_base
install_superman $1
