docker安装注意点
版本暂定为
docker-24.0.9
需要安装docker-compose(最新)

docker用户权限，
```csharp
sudo chown x:x

```
1、把设置容器安装路径到/opt目录下，这样其他data内容不会占用其他空间
2、这个配置有个我不能很好确认的地方，如果不使用"userns-remap": "x"，则会导致docker是用root启动，需要用到sudo chmod 660 /var/run/docker.sock授权，如果使用了，就不能使用docker的hosts模式，根据ai的说法，网桥模式会少20%性能，由于对性能的看重，暂时放弃了使用userns的配置，或许在未来有可以平衡这个的方案
[root@f opt]# cat /etc/docker/daemon.json
```json
{
    "data-root": "/opt/docker_data",
    "insecure-registries": ["dockerhub.top"],
    "registry-mirrors": [
        "https://dockerproxy.com",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com",
        "https://ccr.ccs.tencentyun.com",
        "https://docker.1panel.live/"
    ],
    "ipv6": false
    // "userns-remap": "x" 
}
```

远程主机自动安装脚本
````shell
#!/bin/bash
#定义字体颜色
echo "执行前请先把需要确认当前文件夹下是否有harbor证书、docker安装包、docker-compose文件"
RE='\033[1;31m' # Red color code
GR='\033[1;32m' # Green color code
BL='\033[1;34m' # Blue color code
PU='\033[1;35m' # Purple(紫) color code
SK='\033[1;36m' # SkyBlue(天蓝) color code
NC='\033[0m'    # Reset color to normal

# 检查是否为x用户
if [ "$(whoami)" != "x" ]; then
    echo -e "${RE}错误：请使用x用户执行此脚本${NC}"
    exit 1
fi

# ==================== 确认 Docker 已安装检查 ====================
echo -e "${PU}检查 Docker 是否已安装...${NC}"

if command -v docker &> /dev/null && docker version &> /dev/null; then
    echo -e "${GR}检测到 Docker 已安装并可正常运行！${NC}"
    echo -e "${GR}当前 Docker 版本: $(docker version --format '{{.Server.Version}}')${NC}"
    echo -e "${SK}如需重新安装，请先卸载 Docker 后再执行本脚本。${NC}"
    exit 0
fi

# 额外检查：如果二进制存在但命令不可用，也视为已安装
if [ -f /usr/bin/dockerd ] || [ -f /usr/local/bin/docker ]; then
    echo -e "${GR}检测到 Docker 二进制文件已存在，可能已安装。${NC}"
    echo -e "${SK}建议手动检查后决定是否继续。${NC}"
    read -p "是否强制继续安装？(y/n): " force
    if [[ ! "$force" =~ ^[Yy]$ ]]; then
        echo -e "${RE}已取消安装。${NC}"
        exit 0
    fi
fi

# 检查并添加hosts记录
echo -e "${PU}检查/etc/hosts配置...${NC}"
if ! grep -q "dockerhub.top" /etc/hosts; then
    echo "172.28.0.1 dockerhub.top" | sudo tee -a /etc/hosts > /dev/null
    echo -e "${GR}已添加dockerhub.top到/etc/hosts${NC}"
else
    echo -e "${SK}dockerhub.top已存在于/etc/hosts${NC}"
fi

echo -e "${PU}解压tar包并给与docker权限...${NC}"
if [ -f /opt/soft/docker-24.0.9.tgz ]; then
    tar -xvf /opt/soft/docker-24.0.9.tgz -C /opt/soft
else
    echo -e "${RE}错误：未找到docker的tar包在/opt/soft目录下${NC}"
    exit 1
fi

echo -e "${PU}将docker移到/usr/bin目录下...${NC}"
sudo cp -r /opt/soft/docker/* /usr/bin/

echo -e "${PU}创建docker.service配置文件...${NC}"
sudo tee /etc/systemd/system/docker.service > /dev/null <<-'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
RestartSec=2
ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT
Restart=always
TimeoutStartSec=0
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
Delegate=yes
KillMode=process
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF

echo -e "${PU}创建docker工作目录并创建daemon.json配置文件...${NC}"
sudo mkdir -p /etc/docker && mkdir -p /opt/docker_data
sudo tee /etc/docker/daemon.json > /dev/null <<-'EOF'
{
    "data-root": "/opt/docker_data",
    "insecure-registries": ["sanfu.dockerhub.top"],
    "registry-mirrors": [
        "https://dockerproxy.com",
        "https://hub-mirror.c.163.com",
        "https://mirror.baidubce.com",
        "https://ccr.ccs.tencentyun.com",
        "https://docker.1panel.live/"
    ],
    "ipv6": false,
    #"userns-remap": "sfmobile"
}
EOF

echo -e "${PU}重新加载配置文件并启动docker...${NC}"
sudo systemctl daemon-reload && sudo systemctl start docker

echo -e "${PU}设置docker开机自启动...${NC}"
sudo systemctl enable docker.service

echo -e "${PU}修改docker.sock权限...${NC}"
sudo chown sfmobile:sfmobile /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock

echo -e "${PU}将docker-compose移到/usr/local/bin/目录...${NC}"
sudo cp /opt/soft/docker-compose* /usr/local/bin/docker-compose && \
sudo chmod 755 /usr/local/bin/docker-compose
sudo chown sfmobile:sfmobile /usr/local/bin/docker-compose

echo -e "${PU}######## 验证docker安装结果... ########${NC}"
if ! docker version; then
    echo -e "${RE}docker 安装失败...${NC}"
    exit 1
fi
echo -e "${GR}docker安装成功！！！${NC}"

echo -e "${PU}######## 验证docker-compose安装结果... ########${NC}"
if ! docker-compose -v; then
    echo -e "${RE}docker-compose 安装失败...${NC}"
    exit 1
fi

echo -e "${GR}docker-compose 安装成功！！！${NC}"

echo -e "${GR}安装完成，请确保sfmobile用户可以无需sudo使用docker命令${NC}"
````