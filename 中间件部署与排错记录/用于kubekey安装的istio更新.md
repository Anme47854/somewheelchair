需要提前下载对应版本，
20260528这部分知识不是很稳固，需要在学习后重新回顾一次

##istio更新
```shell
https://github.com/istio/istio/releases/tag/1.20.8
```

```shell
./istioctl install \
    --set hub=istio \
    --set tag=1.20.8 \
    --set addonComponents.prometheus.enabled=false \
    --set values.global.jwtPolicy=first-party-jwt \
    --set values.global.proxy.autoInject=disabled \
    --set values.global.tracer.zipkin.address="jaeger-collector.istio-system.svc:9411" \
    --set values.sidecarInjectorWebhook.enableNamespacesByDefault=true \
    --set values.global.imagePullPolicy=IfNotPresent \
    --set revision=1-20-8
```
```shell
docker pull istio/proxyv2:1.20.8
docker pull istio/pilot:1.20.8
```


##jaeger更新
```shell
docker pull jaegertracing/jaeger-operator:1.60.0
docker pull jaegertracing/all-in-one:1.60.0
docker pull jaegertracing/jaeger-collector:1.60.0
docker pull jaegertracing/jaeger-query:1.60.0
docker pull jaegertracing/jaeger-agent:1.60.0
docker pull jaegertracing/jaeger-ingester:1.60.0

docker tag jaegertracing/jaeger-operator:1.60.0 sfharbordev.sanfu.com/istio/jaeger-operator:1.60.0
docker tag jaegertracing/all-in-one:1.60.0 sfharbordev.sanfu.com/istio/all-in-one:1.60.0
docker tag jaegertracing/jaeger-collector:1.60.0 sfharbordev.sanfu.com/istio/jaeger-collector:1.60.0
docker tag jaegertracing/jaeger-query:1.60.0 sfharbordev.sanfu.com/istio/jaeger-query:1.60.0
docker tag jaegertracing/jaeger-agent:1.60.0 sfharbordev.sanfu.com/istio/jaeger-agent:1.60.0
docker tag jaegertracing/jaeger-ingester:1.60.0 sfharbordev.sanfu.com/istio/jaeger-ingester:1.60.0

docker save sfharbordev.sanfu.com/istio/jaeger-operator:1.60.0 -o jaeger-operator.tar
docker save sfharbordev.sanfu.com/istio/all-in-one:1.60.0 -o all-in-one.tar
docker save sfharbordev.sanfu.com/istio/jaeger-collector:1.60.0 -o jaeger-collector.tar
docker save sfharbordev.sanfu.com/istio/jaeger-query:1.60.0 -o jaeger-query-1.60.0.tar
docker save sfharbordev.sanfu.com/istio/jaeger-agent:1.60.0 -o jaeger-agent-1.60.0.tar
docker save sfharbordev.sanfu.com/istio/jaeger-ingester:1.60.0 -o jaeger-ingester-1.60.0.tar

docker load -i jaeger-operator.tar
docker load -i all-in-one.tar
docker load -i jaeger-collector.tar
docker load -i jaeger-query-1.60.0.tar
docker load -i jaeger-agent-1.60.0.tar
docker load -i jaeger-ingester-1.60.0.tar

docker push sfharbordev.sanfu.com/istio/jaeger-operator:1.60.0
docker push sfharbordev.sanfu.com/istio/all-in-one:1.60.0
docker push sfharbordev.sanfu.com/istio/jaeger-collector:1.60.0
docker push sfharbordev.sanfu.com/istio/jaeger-query:1.60.0
docker push sfharbordev.sanfu.com/istio/jaeger-agent:1.60.0
docker push sfharbordev.sanfu.com/istio/jaeger-ingester:1.60.0
```
jaeger-operator 的 ClusterRole 添加权限
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jaeger-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "endpoints", "persistentvolumeclaims", "events", "configmaps", "secrets", "namespaces"]
  verbs: ["*"]

- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets", "replicasets", "statefulsets"]
  verbs: ["*"]

- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]

- apiGroups: ["jaegertracing.io"]
  resources: ["jaegers"]
  verbs: ["*"]

- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "ingressclasses"]
  verbs: ["*"]
```
确保权限绑定
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jaeger-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jaeger-operator
subjects:
- kind: ServiceAccount
  name: jaeger-operator
  namespace: istio-system
```
确认webhook是否有可用证书
```shell
kubectl -n istio-system get secret | grep jaeger
##安装cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.1/cert-manager.yaml
#创建 Issuer/Certificate CRD，生成 webhook TLS 证书
# jaeger-issuer.yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: jaeger-selfsign
  namespace: istio-system
spec:
  selfSigned: {}
#执行
kubectl apply -f jaeger-issuer.yaml
#创建 CRD
# jaeger-webhook-cert.yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: jaeger-operator-webhook-cert
  namespace: istio-system
spec:
  secretName: jaeger-operator-webhook-cert   # 生成的 Secret 名称
  commonName: jaeger-operator.istio-system.svc
  dnsNames:
    - jaeger-operator.istio-system.svc
  issuerRef:
    name: jaeger-selfsign
    kind: Issuer
  duration: 8760h       # 证书有效期 1 年
  renewBefore: 360h     # 提前 15 天续签
#执行
kubectl apply -f jaeger-webhook-cert.yaml
#在 Jaeger Operator Deployment 中挂载 Secret
#证书到期时 Cert-Manager 会自动续签
#检查并挂载证书到/tmp/k8s-webhook-server/serving-certs
kubectl -n istio-system get certificate jaeger-operator-webhook-cert
kubectl -n istio-system get secret jaeger-operator-webhook-cert


```
修改jaeger-operator版本即可更新


##kiali
需要修改configmap的配置
```yaml
external_services:
  istio:
    url_service_version: http://istiod.istio-system:15014/version
```
更新后需要执行
kiali创建密钥
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kiali
  namespace: istio-system
data:
## echo -n admin |  base64
#YWRtaW4=
  username: YWRtaW4=
  passphrase: YWRtaW4=
```
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kiali-service-account-token
  namespace: istio-system
  annotations:
    kubernetes.io/service-account.name: kiali-service-account
  labels:
    app: kiali
    app.kubernetes.io/instance: kiali
    app.kubernetes.io/name: kiali
    app.kubernetes.io/part-of: kiali
    app.kubernetes.io/version: v1.50
    version: v1.50
type: kubernetes.io/service-account-token
```


非可用toeken记录
```shell
curl -X POST 'https://<KS-APISERVER>/oauth/token' -H 'Content-Type: application/x-www-form-urlencoded' --data-urlencode 'grant_type=password' --data-urlencode 'username=admin' --data-urlencode 'password=P@88w0rd' --data-urlencode 'client_id=kubesphere' --data-urlencode 'client_secret=kubesphere'
```
