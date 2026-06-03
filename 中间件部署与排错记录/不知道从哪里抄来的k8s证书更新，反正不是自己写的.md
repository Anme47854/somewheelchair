./kk certs check-expiration -f
./kk certs renew -f

```shell
#!/bin/bash
# ............................................................................. 变量定义 ............................................................................. #

# k8s master节点ip
K8S_MASTER_IP=("1.1.1.1" "1.1.1.2" "1.1.1.3")
# k8s work节点ip,如果没有则为空,如果节点同时拥有master和work角色，那么只填写到上面的 master 节点ip， 下面的work节点ip不用填
K8S_WORK_IP=("1.1.1.4")
# 所有节点ip, 包含master和work节点ip
ALL_NODES=("${K8S_MASTER_IP[@]}" "${K8S_WORK_IP[@]}")
# 定义k8s配置文件路径
CONFIG_FILE="/etc/kubernetes/kubeadm-config.yaml"
# 获取当前时间，格式为年月日时分秒
CURRENT_TIME=$(date +"%Y%m%d%H%M%S")
# 红色字体
RED='\033[0;31m'
# 黄色字体
YELLOW='\033[1;33m'
# 绿色字体
GREEN='\033[0;32m'
# 重置颜色, 恢复默认颜色
NC='\033[0m'
# 加粗字体
BOLD='\033[1m'


# ............................................................................. 脚本须知 ............................................................................. #

echo -e "\n${BOLD}${RED}使用脚本须知${NC}"
echo -e "\n${RED} - 这个脚本只能在保存完整的kubeadm-config.yaml配置文件节点上执行,默认在k8s-master-01节点上执行${NC}\n"
echo -e "\n${RED} - 这个脚本的容器运行时是containerd,如果是docker或者其他,需要全局替换containerd为相应的容器运行时${NC}\n"
echo -e "\n${RED} - 这个脚本适用于etcd采用二进制安装的k8s集群,非 etcd 容器化部署在k8s中的环境。${NC}\n"
echo -e "\n${RED} - 使用kubernetes根证书ca.crt更新脚本使用须知:更新ca证书属于危险操作,生产环境使用请先在测试环境中测试通过后再用,使用前请做好备份！！！！！！${NC}\n"
echo -e "\n${YELLOW} - 如果想实现证书过期时间为100年,需要提前编译kubeadm到100年,参考https://blog.csdn.net/weixin_50902636/article/details/145120936${NC}\n"
echo -e "\n${RED} - 使用脚本需提前定义好该脚本中的变量,主要是k8s节点ip${NC}\n"
read -p "$(echo -e ${YELLOW}如果你已经确认脚本使用须知，请输入 yes 确认继续操作，输入其他内容将退出脚本[yes/no]: ${NC})" user_input
if [ "$user_input" != "yes" ]; then
    echo -e "\n${GREEN}用户取消操作，脚本退出。${NC}\n"
    exit 1
fi


# ............................................................................. 基础软件安装 ............................................................................. #

echo -e "\n${YELLOW}1. 基础软件检测和安装 ${NC}\n"
if ! command -v yq &> /dev/null
then
    echo "\n${RED} - 1.1 yq 未安装，开始下载 ${NC}\n"
    wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
    if [ $? -eq 0 ]; then
        echo "\n${YELLOW} - 1.2 yq 下载成功，添加执行权限 ${NC}\n"
        echo "\n${YELLOW} - 1.3 为yq命令添加执行权限 ${NC}\n"
        chmod +x /usr/local/bin/yq
        echo "\n${YELLOW} - 1.4 yq 安装完成 ${NC}\n"
    else
        echo "\n${RED} - 1.2 yq 下载失败，请检查网络或手动下载 ${NC}\n"
        exit 1
    fi
fi
    

# ............................................................................. 函数定义 ............................................................................. #

# 定义一个函数来处理节点的 SSH 密钥分发
distribute_ssh_key() {
    local ip=$1
    echo -e "\n${GREEN} - 2.5 尝试连接到k8s节点-$ip ${NC}\n"
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$ip" "exit" 2>/dev/null
    if [ $? -eq 0 ]; then
        if ! ssh "$ip" "grep -q '$LOCAL_PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null"; then
            echo -e "\n${YELLOW} - 2.6 k8s节点-$ip 的 authorized_keys 文件中不存在本地公钥, 将本地公钥添加到远程节点的 authorized_keys 文件中 ${NC}\n"
            ssh-copy-id -o StrictHostKeyChecking=no "$ip"
        else
            echo -e "\n${GREEN} - 2.6  k8s节点-$ip 的 authorized_keys 文件中已存在本地公钥 ${NC}\n"
        fi
    else
        echo -e "\n${RED} - 2.6 无法连接到k8s节点-$ip, 请检查网络和节点状态。${NC}\n"
        exit 1
    fi
}


# ............................................................................. 免密登录 ............................................................................. #

echo -e "\n${YELLOW}2. 为所有k8s节点配置免密登录 ${NC} \n"
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo -e "\n${YELLOW} - 2.1 本地 SSH 公钥不存在, 开始生成新的 SSH 密钥对 ${NC}\n"
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    echo -e "\n${YELLOW} - 2.2 SSH 密钥对生成完成 ${NC}\n"
fi

echo -e "\n${GREEN} - 2.3 获取本地公钥内容 ${NC}\n"
LOCAL_PUB_KEY=$(cat ~/.ssh/id_rsa.pub)

echo -e "\n${YELLOW} - 2.4 下发公钥到所有k8s节点 ${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    distribute_ssh_key "$ip"
done  


# ............................................................. 备份k8s相关文件,停止kubelet服务,删除旧的相关文件 ................................................................ #

echo -e "\n${YELLOW}3. 备份k8s相关文件,停止kubelet服务,删除旧的相关文件 ${NC} \n"
for ip in "${ALL_NODES[@]}"; do
    echo -e "\n${YELLOW} - 3.1 在节点 $ip 备份k8s相关文件 ${NC}\n"
    ssh $ip "mkdir -p /root/k8s-backup && cp -rp /etc/kubernetes/ /root/k8s-backup/$CURRENT_TIME-kubernetes/"
    echo -e "\n${YELLOW} - 3.2 在节点 $ip 上停止kubelet服务 ${NC}\n"
    ssh $ip "systemctl stop kubelet"
    echo -e "\n${YELLOW} - 3.3 在节点 $ip 上删除原来的配置 ${NC}\n"
    ssh $ip "rm -rf /etc/kubernetes/pki/* /etc/kubernetes/*.conf /var/lib/kubelet/pki/*"
done


# ............................................................. 生成新的证书,并下发到其他节点 ................................................................ #

echo -e "\n${YELLOW}4. 生成新的证书,并下发到其他节点 ${NC}\n"
echo -e "\n${YELLOW} - 4.1 完善k8s配置文件中的第一个文档里的 certSANs 列表 ${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    echo -e "\n${YELLOW} - - 4.1.1 解析主机名 ${NC}\n"
    hostname=$(getent hosts "$ip" | awk '{print $3}')
    echo -e "\n${YELLOW} - - 4.1.2 解析主机域名 ${NC}\n"
    hostname_cluster=$(getent hosts "$ip" | awk '{print $2}')
    echo -e "\n${YELLOW} - - 4.1.3 检查目标 IP 是否存在于第一个文档的 certSANs 列表中 ${NC}\n"
    if ! yq e '(select(document_index == 0) | .apiServer.certSANs[])' "$CONFIG_FILE" | grep -q "$ip"; then
        echo -e "\n${YELLOW} - - 4.1.4 检查目标 ip: $ip 不存在于第一个文档的 certSANs 列表中,将其加入到列表中 ${NC}\n"
        yq e '(select(document_index == 0) | .apiServer.certSANs) += ["'"$ip"'"]' -i "$CONFIG_FILE"
    fi
    if ! yq e '(select(document_index == 0) | .apiServer.certSANs[])' "$CONFIG_FILE" | grep -q "$hostname"; then
        echo -e "\n${YELLOW} - - 4.1.5 检查目标 主机名: $hostname 不存在于第一个文档的 certSANs 列表中,将其加入到列表中 ${NC}\n"
        yq e '(select(document_index == 0) | .apiServer.certSANs) += ["'"$hostname"'"]' -i "$CONFIG_FILE"
    fi
    if ! yq e '(select(document_index == 0) | .apiServer.certSANs[])' "$CONFIG_FILE" | grep -q "$hostname_cluster"; then
        echo -e "\n${YELLOW} - - 4.1.6 检查目标 主机域名: $hostname_cluster 不存在于第一个文档的 certSANs 列表中,将其加入到列表中 ${NC}\n"
        yq e '(select(document_index == 0) | .apiServer.certSANs) += ["'"$hostname_cluster"'"]' -i "$CONFIG_FILE"
    fi
done
cat $CONFIG_FILE

echo -e "\n${YELLOW} - 4.2 生成新的证书 ${NC}\n"
for i in ca apiserver apiserver-kubelet-client front-proxy-ca front-proxy-client; do    
    kubeadm init phase certs $i --config $CONFIG_FILE
done

echo -e "\n${YELLOW} - 4.3 生成新的管理员账户 ${NC}\n"
kubeadm init phase certs sa

echo -e "\n${YELLOW} - 4.4 下发证书到其他节点 ${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    scp /etc/kubernetes/pki/* $ip:/etc/kubernetes/pki/
done 


# ............................................................. 生成新的配置文件,并下发到其他节点 ................................................................ #

echo -e "\n${YELLOW}5. 生成新的k8s admin controller-manager scheduler kubelet 配置文件 ${NC}\n"

echo -e "\n${YELLOW} - 5.1 下发完整的kubeadm-config.yaml配置文件到所有节点 ${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    scp /etc/kubernetes/kubeadm-config.yaml $ip:/etc/kubernetes/kubeadm-config.yaml
done

echo -e "\n${YELLOW} - 5.2 在所有master节点上生成完整的配置文件 ${NC}\n"
for ip in "${K8S_MASTER_IP[@]}"; do
    ssh $ip "kubeadm init phase kubeconfig all --config /etc/kubernetes/kubeadm-config.yaml"
done

echo -e "\n${YELLOW} - 5.3 在所有work节点生成 kubelet.conf ${NC}\n"
for ip in "${K8S_WORK_IP[@]}"; do
    ssh $ip "kubeadm init phase kubeconfig kubelet --config /etc/kubernetes/kubeadm-config.yaml"
done


# ............................................................. 重载配置并重启所有节点的kubelet服务 ................................................................ #

echo -e "\n${YELLOW}6. 重载配置并重启所有节点的kubelet服务${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    ssh $ip "systemctl daemon-reload && systemctl restart kubelet && systemctl restart containerd"
    sleep 10
done


# ............................................................. 替换kubectl新的管理员配置文件 ................................................................ #

echo -e "\n${YELLOW}7. 替换kubectl新的管理员配置文件${NC}\n"
for ip in "${K8S_MASTER_IP[@]}"; do
    ssh $ip "rm -rf $HOME/.kube"
    ssh $ip "unset KUBECONFIG"
    ssh $ip "export KUBECONFIG=/etc/kubernetes/admin.conf"
    ssh $ip "mkdir -p $HOME/.kube"
    ssh $ip "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config"
    ssh $ip "sudo chown $(id -u):$(id -g) $HOME/.kube/config"
done


# ............................................................. 重启 kube-apiserver, kube-controller-manager, kube-scheduler ................................................................ #


echo -e "\n${YELLOW}8. 重启 kube-apiserver, kube-controller-manager, kube-scheduler ${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    ssh $ip "crictl ps |grep -E 'kube-apiserver|kube-controller-manager|kube-scheduler' | awk -F ' ' '{print $1}' |xargs crictl rm -f"
    ssh $ip "crictl ps -a -q -s Exited | xargs crictl rm -f"
    sleep 10
done


# .................................................... 重启 calico-node, calico-kube-controllers, kube-proxy, coredns, nodelocaldns组件 ................................................. #

echo -e "\n${YELLOW}9. 重启 calico-node, calico-kube-controllers, kube-proxy, coredns, nodelocaldns组件${NC}\n"
kubectl -n kube-system delete pods -l k8s-app=calico-node --force
kubectl -n kube-system delete pods -l k8s-app=calico-kube-controllers --force
kubectl -n kube-system delete pods -l k8s-app=kube-proxy --force
kubectl -n kube-system delete pods -l k8s-app=kube-dns --force
kubectl -n kube-system delete pods -l k8s-app=nodelocaldns --force
sleep 10


# .................................................... 自动批准 Kubernetes 集群中所有待处理的证书签名请求(CSR) ................................................. #

echo -e "\n${YELLOW}10. 自动批准 Kubernetes 集群中所有待处理的证书签名请求(CSR)${NC}\n"
for i in $(kubectl get csr | awk 'NR > 1{print $1}'); do
    kubectl certificate approve $i
done


# .................................................... 更新集群配置文件configmap: kubeadm-config 和 kubelet-config ................................................. #

echo -e "\n${YELLOW}11. 更新集群配置文件configmap: kubeadm-config 和 kubelet-config${NC}\n"
kubeadm init phase upload-config all --config /etc/kubernetes/kubeadm-config.yaml


# .................................................... 更新集群信息文件configmap: cluster-info ................................................. #

echo -e "\n${YELLOW}12. 更新集群信息文件configmap: cluster-info${NC}\n"
base64_encoded_ca="$(base64 -w0 /etc/kubernetes/pki/ca.crt)"
kubectl get cm/cluster-info --namespace kube-public -o yaml | \
    /bin/sed "s/\(certificate-authority-data:\).*/\1 ${base64_encoded_ca}/" | \
    kubectl apply -f -


# .................................................... 对于使用了serviceAccount 的所有pods进行重启 ................................................. #

echo -e "\n${YELLOW}13. 对于使用了serviceAccount 的所有pods进行重启, 这个操作也会重启calico-node, calico-kube-controllers, kube-proxy, coredns, nodelocaldns组件${NC}\n"
for namespace in $(kubectl get namespace -o jsonpath='{.items[*].metadata.name}'); do
    for name in $(kubectl get deployments -n $namespace -o jsonpath='{.items[*].metadata.name}'); do
        kubectl patch deployment -n ${namespace} ${name} -p '{"spec":{"template":{"metadata":{"annotations":{"ca-rotation": "1"}}}}}';
    done
    for name in $(kubectl get daemonset -n $namespace -o jsonpath='{.items[*].metadata.name}'); do
        kubectl patch daemonset -n ${namespace} ${name} -p '{"spec":{"template":{"metadata":{"annotations":{"ca-rotation": "1"}}}}}';
    done
    for name in $(kubectl get statefulset -n $namespace -o jsonpath='{.items[*].metadata.name}'); do
        kubectl patch statefulset -n ${namespace} ${name} -p '{"spec":{"template":{"metadata":{"annotations":{"ca-rotation": "1"}}}}}';
    done
done


# .................................................... 删除所有节点上容器状态为 Exited 的容器 ................................................. #

echo -e "\n${YELLOW}14. 删除所有节点上容器状态为 Exited 的容器 ${NC}\n"
for ip in "${ALL_NODES[@]}"; do
    ssh $ip "crictl ps -a -q -s Exited | xargs crictl rm -f"
    sleep 10
done
```