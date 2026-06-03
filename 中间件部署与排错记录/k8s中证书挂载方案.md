有些证书不想放容器里面打包，可以考虑volume挂载的方案
须知
**命名必须符合 DNS 子域名规范，只能使用小写字母、数字、短横线 - 或点 .。**
xxx-xxx

到k8s集群上使用指令导入两个证书
分配至指定namespace
#####微信服务商支付证书 ksh_apiclient_cert
```shell
kubectl create secret generic ksh-apiclient-cert \
   --from-file=key.pem=./=key.pem \
   --namespace=xx
```
