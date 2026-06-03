ingress不再维护，使用higress

官方的标准安装方案为helm直接安装(报错就找istio)
```shell
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

helm repo add higress.io https://higress.cn/helm-charts

helm install higress -n higress-system higress.io/higress --create-namespace --render-subchart-notes
```
实际部署时controller和gateway会无法启动
gateway无法启动的原因是需要
‘istio-ca-root-cert/root-cert.pem’证书，可以执行以下指令拷贝
```shell
kubectl get configmap istio-ca-root-cert -n istio-system -o yaml |   sed 's/name: istio-ca-root-cert/name: higress-ca-root-cert/' |   sed 's/namespace: istio-system/namespace: higress-system/' |   kubectl apply -f -
```
修改类型
```shell
helm upgrade higress higress.io/higress -n higress-system   --set higress-core.gateway.service.type=ClusterIP   --reuse-values
```
controller无法启动是会调用到istio网格服务，实际上我们也不需要网格服务
```shell
helm upgrade higress higress.io/higress -n higress-system   --set global.enableGatewayAPI=false   --reuse-values
```

暂未开放higress的nodeport和cluserip，使用pod+port的方式访问管理台
找到higress-console，获取
本次示例百货测试环境
访问console pod
http://10.233.108.26:8080/route
admin/Sanfu2066.
1、为higress-gateway添加外部访问方式（目前使用nodeport）
2、在左侧列表点击-域名管理-添加域名
bh.k8s.sanfu.cluster.local，并且新增节点hosts域名映射
3、在左侧列表点击-路由配置-创建路由
添加路名称、域名、路径与目标服务（其他配置酌情添加）
保存后点击策略-重写（配置）-开启重写策略-重写路径为"前缀重写 /"

目前方案和未来目标
未来目标，外部请求直接到higress（理论上最好的是适配云厂SLB）
当前还是保留nginx访问到后端的方案
nginx upstream->higress
需要修改higress-gateway的nodeport端口
在proxy_pass http://ms-sanfu-spi-platcustomer/ 中，去掉最后的/，让nginx转发完整的请求路径到higress

由于有个业务要求使用kong，妥协的处理方案为kong关闭strip path和开启Preserve hosts，其他配置照旧


