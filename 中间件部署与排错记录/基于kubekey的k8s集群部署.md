目前市面上有些快速部署方案，选择快速部署的原因是当前公司运维整体能力较弱，开发团队也不需要什么个性功能，不需要定制化k8s，基础业务够用就行 

正常应该让同事使用二进制搭建集群，这样能够加深系统流程理解，没法子只能这样了

**该部署方案基于以上考虑编写，k8s系统出问题解决不掉就快速重新部署，有能力能解决就自己解决**

通过对管理平台的筛选和当前时间(2025年8月13日)k8s版本（1.28，大部分平台适应这个版本）的选择

2026年0527，重新回顾这个文本的时候想起来中间件kubekey删库跑路了一次，这个部署可能也不合适了，未来可能还是需要二进制部署

## 当前市面上推荐安装方式
1、kubeadm
```shell
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
```
2、kind（docker启动k8s，用于单机测试可以）
```shell
https://kind.sigs.k8s.io/
```
3、kubekey
```shell
https://github.com/kubesphere/kubekey
```
4、Rainbond
```shell
https://www.rainbond.com/docs/installation/install-with-ui
```
5、二进制安装
6、待补充（其他方案，给公司的文档存留了空间，让后续接手的人可以补充）

## 本次部署k8s，将基于kubekey安装k8s集群
为保证系统处于最佳状态，先下载rainbond官方的系统优化脚本(2025.08.13)
```shell
https://get.rainbond.com/linux-system-optimize.sh
```
避免公rainbond公司删库跑路，脚本存到了该文档目录下

### 1、修改系统hostname
由于Kubernetes暂不支持大写NodeName，hostname中包含大写字母将导致后续安装过程无法正常结束，需要把大写的hostname修改为小写
```shell
hostnamectl set-hostname {小写hostname}
```
### 2、执行优化脚本
```shell
sh linux-system-optimize.sh
```
会提示重启系统，reboot就行
### 3、安装系统依赖
```shell
# 安装 Kubernetes 系统依赖包
yum install curl socat conntrack ebtables ipset ipvsadm
# 更多的工具
yum install wget jq psmisc vim net-tools telnet yum-utils device-mapper-persistent-data lvm2 git ntpdate keepalived haproxy conntrack socat  -y
```

### 4、下载kubekey
设置中文区
```shell
export KKZONE=cn
curl -sfL https://get-kk.kubesphere.io | sh -
```

### 5、获取安装包镜像名称
获取与本地安装包yaml模板
```shell
./kk create manifest --with-kubernetes v1.28.15 --with-registry
```
查看镜像来源
```shell
cat manifest-sample.yaml
##修改文件中镜像获取地址
#原registry.cn-beijing.aliyuncs.com已经不能使用，需要本地修改镜像地址
#修改完成后使用以下指令做成离线包
./kk artifact export -m manifest-sample.yaml -o kubernets.tar.gz
```

### 6、配置kk文件
检索支持的k8s版本
推荐选择双数版本，最少补丁版本数超过5。
不建议选择太老的版本，（202050814）时v1.30已经发布。
本次选择v1.28.15，于202050814时检索的双数最新版。
```shell
./kk version --show-supported-k8s
```
创建安装yaml
```shell
./kk create config -f k8s-v12815.yaml --with-kubernetes v1.28.15
```
修改配置文件
```shell
hosts：指定节点的 IP、ssh 用户、ssh 密码、ssh 端口
roleGroups：指定 3 个 etcd、control-plane 节点，复用相同的机器作为 3 个 worker 节点
control-plane：平面控制
etcd：集群配置和状态数据
internalLoadbalancer： 启用内置的 HAProxy 负载均衡器
domain：自定义域名 lb.opsxlab.cn，没特殊需求可使用默认值 lb.kubesphere.local，公司的话就改为lb.kubernetes.sanfu.com
clusterName：自定义 opsxlab.cn，没特殊需求可使用默认值 cluster.local
autoRenewCerts：该参数可以实现证书到期自动续期，默认为 true
containerManager：使用 containerd
```
服饰测试环境安装文件如下
```shell
[root@k8s-master01 kubekey]# cat k8s-v12815.yaml

apiVersion: kubekey.kubesphere.io/v1alpha2
kind: Cluster
metadata:
  name: sample
spec:
  hosts:
  - {name: k8s-master01, address: 172.28.0.1 ,port: 22, internalAddress: 172.28.0.1, user: root, password: "xxxxx"}
  - {name: k8s-master02, address: 172.28.0.2 ,port: 22, internalAddress: 172.28.0.2, user: root, password: "xxxxx"}
  - {name: k8s-master03, address: 172.28.0.3 ,port: 22, internalAddress: 172.28.0.3, user: root, password: "xxxxx"}
  - {name: k8s-node01, address: 172.28.0.4 ,port: 22, internalAddress: 172.28.0.4, user: root, password: "xxxxx"}
  - {name: k8s-node02, address: 172.28.0.5 ,port: 22, internalAddress: 172.28.0.5, user: root, password: "xxxxx"}
  - {name: k8s-node03, address: 172.28.0.6 ,port: 22, internalAddress: 172.28.0.6, user: root, password: "xxxxx"}
  roleGroups:
    etcd:
    - k8s-master01
    - k8s-master02
    - k8s-master03
    control-plane:
    - k8s-master01
    - k8s-master02
    - k8s-master03
    worker:
    - k8s-node01
    - k8s-node02
    - k8s-node03
  controlPlaneEndpoint:
    ## Internal loadbalancer for apiservers
    # internalLoadbalancer: haproxy

    domain: lb.kubernetes.com
    address: ""
    port: 6443
  kubernetes:
    version: v1.28.15
    clusterName: cluster.local
    autoRenewCerts: true
    containerManager: containerd
  etcd:
    type: kubekey
  network:
    plugin: calico
    kubePodsCIDR: 10.233.64.0/18
    kubeServiceCIDR: 10.233.0.0/18
    ## multus support. https://github.com/k8snetworkplumbingwg/multus-cni
    multusCNI:
      enabled: false
  registry:
    privateRegistry: ""
    namespaceOverride: ""
    registryMirrors: []
    insecureRegistries: []
  addons: []
```

### 7、安装harbor（如果已经安装跳过）

7.1、可以使用kk安装harbor，使用以下指令
```shell
./kk init registry -f config-sample.yaml -a kubesphere.tar.gz
```

7.2、其他安装方案请参考其他文章

### 8、k8s集群安装
如果有离线包
```shell
./kk create cluster -f config-sample.yaml -a kubesphere.tar.gz --with-local-storage --skip-push-images
```
如果本地harbor上有镜像，可以直接使用以下指令来安装
```shell
./kk create cluster -f k8s-v12815.yaml
```

### 9、rancher相关
当时还要抉择一个开源的管理平台，选了rancher
rancher的硬性需求是Ingress Controller
安装Ingress Controller如下
```shell
官方nginx-ingress.yaml
https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
#由于国内镜像问题，需要自己修改镜像源
#搜索image相关，修改镜像源地址后执行
使用
kubectl apply -f deploy.yaml
或者
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```
Ingress的网络需要外部访问的话还需要MetalLB
20260527回顾：ingress今年的时候关闭更新，后续可以选择higress

### 10、部分注意事项
#### hosts映射配置
在coredns配置中需要单独添加hosts映射时，需要注意格式和配置，不然会导致集群页面无法访问
指令
kubectl edit configmap coredns -n kube-system
```json
.:53 {
    errors
    health {
      lameduck 5s
    }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
      ttl 30
    }
    hosts {
      172.28.2.1   nameserver1
      fallthrough
    }
    prometheus :9153
    forward . /etc/resolv.conf {
      prefer_udp
      max_concurrent 1000
    }
    cache 30
    loop
    reload
    loadbalance
}
```
在nodelocaldns配置中修改.:53
kubectl edit configmap nodelocaldns -n kube-system
```json
.:53 {
    errors
    cache 30
    reload
    loop
    bind 169.254.25.10
    forward . 10.233.0.3 {
        force_tcp
    }
    prometheus :9253
}
```
#### 扩大端口数量
默认路径
/etc/kubernetes/manifests/kube-apiserver.yaml
在文件中新增--service-node-port-range=8000-52767
```yaml
spec:
  containers:
  - command:
    - kube-apiserver
    ##新增
    - --service-node-port-range=8000-52767
    - --advertise-address=172.28.0.1
```

#### 合理使用启动探针、存活探针
```yaml
          startupProbe:
            httpGet:
              path: /actuator/health
              port: 80
              scheme: HTTP
            initialDelaySeconds: 30
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 10
```