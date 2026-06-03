##使用评价、全面但是不够直观

资源不足穷成一坨的skywalking单机部署方式，用于测试是否符合符合开发使用
容器网络，确保相互访问
```shell
docker network create skywalking-shared-net
```
es、oap、ui、分开部署

skywalking-es
[root@f skywalking]# cat skywalking-es/docker-compose.yaml 
```yaml
version: '3.8'
services:
  skywalking-es:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
    container_name: skywalking-es
    restart: unless-stopped
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms1g -Xmx1g"
      - xpack.security.enabled=false
    ports:
      - "9200:9200"
    volumes:
      - /opt/skywalking/skywalking-es/data:/usr/share/elasticsearch/data
      - /opt/skywalking/skywalking-es/logs:/usr/share/elasticsearch/logs
    networks:
      - skywalking-shared-net
    ulimits:
      memlock:
        soft: -1
        hard: -1

networks:
  skywalking-shared-net:
    external: true
```
skywalking-oap
[root@f skywalking]# cat skywalking-oap/docker-compose.yaml 
```yaml
version: '3.8'
services:
  skywalking-oap:
    image: apache/skywalking-oap-server:9.4.0
    container_name: skywalking-oap
    restart: unless-stopped
    environment:
      - SW_STORAGE=elasticsearch
      - SW_STORAGE_ES_CLUSTER_NODES=skywalking-es:9200
      - JAVA_OPTS=-Xms2048m -Xmx2048m
    ports:
      - "11800:11800"
      - "12800:12800"
    networks:
      - skywalking-shared-net

networks:
  skywalking-shared-net:
    external: true
```
skywalking-ui
[root@f skywalking]# cat skywalking-ui/docker-compose.yaml 
```yaml
version: '3.8'

services:
  skywalking-ui:
    image: apache/skywalking-ui:9.4.0
    container_name: skywalking-ui
    restart: unless-stopped
    environment:
      - SW_OAP_ADDRESS=http://skywalking-oap:12800
    ports:
      - "8088:8080"
    networks:
      - skywalking-shared-net

networks:
  skywalking-shared-net:
    external: true
```
#####方案一
Mutating Admission Webhook 自动注入
```yaml
当kubectl apply 一个 deployment资源后,k8s会创建pod，此时k8s根据mutatingwebhookconfigurations资源配置(配置了监控的资源以及webhook server信息)，调用相应的webhook server，webhook server会进行处理，在pod yaml中注入initContainer配置，使业务容器与initContainer容器共享skywalking agent目录，并且配置JAVA_TOOL_OPTIONS环境变量值为"-javaagent:/sky/agent/skywalking-agent.jar=agent.service_name=xxxx",这样JVM启动时，会附加上javaagent,以达到目的。
```
下载解压
```shell
https://dlcdn.apache.org/skywalking/swck/0.9.0/skywalking-swck-0.9.0-bin.tgz
```
需要准备镜像
```shell
skywalking-java-agent:8.16.0-java8
skywalking-swck:v0.9.0
kube-rbac-proxy:v0.11.0
```
执行
```shell
kubectl apply -f config/operator-bundle.yaml
kubectl apply config/adapter-bundle.yaml
```
创建自动注入agent
```shell
cat <<EOF | kubectl apply -f -
apiVersion: operator.skywalking.apache.org/v1alpha1
kind: SwAgent
metadata:
  name: sw-agent
  namespace: skywalking-swck-system
spec:
  containerMatcher: ".*"
  javaSidecar:
    #这里需要使用自己的镜像
    image: skywalking-java-agent:8.16.0-java8
    env:
    #这部分是skywalking的opa端口
    - name: SW_AGENT_COLLECTOR_BACKEND_SERVICES
      value: "172.28.40.87:11800"
    - name: SW_AGENT_TRACE_IGNORE_PATH
      value: "GET:/actuator/health"
EOF
```
需要注入的命名空间和deloypment需要添加如下配置
```shell
kubectl label namespace {需要开放的命名空间} swck-injection=enabled
```
##注意，由于使用了skywalking的自动注入，所以java_tool_options会被覆盖，需要使用新的参数来配置该项
```yaml
spec:
  template:
    metadata:
      creationTimestamp: null
      labels:
        swck-java-agent-injected: 'true'
      annotations:
        sidecar.skywalking.apache.org/env.Name: JAVA_TOOL_OPTIONS
        sidecar.skywalking.apache.org/env.Value: '-javaagent:/sky/agent/skywalking-agent.jar -Xmx512m -Xms512m'
        sidecar.skywalking.apache.org/initcontainer.Image: 'skywalking-java-agent:8.16.0-java8'
    spec:
      containers:
          env:
            - name: SW_AGENT_COLLECTOR_BACKEND_SERVICES
              value: '172.28.40.87:11800'
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.namespace
            - name: APP_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: 'metadata.labels[''app'']'
            - name: SW_AGENT_INSTANCE_NAME
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: metadata.name
            - name: SW_AGENT_NAME
              value: '$(POD_NAMESPACE)::$(APP_NAME)'
```

####方案二
制作apm基础镜像，将apache-skywalking-apm-6.6.0.tar.gz放入/opt/下解压

####方案三
Init Container+ Volume 挂载

方案四
使用官方镜像



如果有namespace启动了一批应用，又不想手动添加自动注入配置，可以使用这个脚本=批量添加yaml文件内容
##注意，该脚本中没有涉及java_tool_options的配置，需要自己手动修改
```shell
#!/bin/bash
# =============================================
# SkyWalking Java Agent 批量注入 + Service Group 自动配置
# =============================================

NS="${1:-$应用前缀}"
FILTER_LABEL="${2:-}"

echo "🚀 开始在 Namespace [$NS] 中注入 SkyWalking Java Agent..."

# 获取 Deployment 列表
if [ -n "$FILTER_LABEL" ]; then
    DEPLOYMENTS=($(kubectl get deployment -n "$NS" -l "$FILTER_LABEL" -o jsonpath='{.items[*].metadata.name}'))
else
    DEPLOYMENTS=($(kubectl get deployment -n "$NS" -o jsonpath='{.items[*].metadata.name}'))
fi

if [ ${#DEPLOYMENTS[@]} -eq 0 ]; then
    echo "⚠️ 没有找到 Deployment"
    exit 0
fi

echo "找到 ${#DEPLOYMENTS[@]} 个 Deployment"
echo "========================================"

COUNT_SUCCESS=0
COUNT_SKIPPED=0
COUNT_FAILED=0

for DEPLOYMENT in "${DEPLOYMENTS[@]}"; do
    echo "🔧 处理: $DEPLOYMENT"

    # 检查是否已注入
    INJECTED=$(kubectl get deployment "$DEPLOYMENT" -n "$NS" \
        -o jsonpath='{.spec.template.metadata.labels.swck-java-agent-injected}' 2>/dev/null)

    if [ "$INJECTED" = "true" ]; then
        echo "   ⏭️ 已注入，跳过"
        ((COUNT_SKIPPED++))
        continue
    fi

    # 获取第一个容器名称
    CONTAINER_NAME=$(kubectl get deployment "$DEPLOYMENT" -n "$NS" \
        -o jsonpath='{.spec.template.spec.containers[0].name}' 2>/dev/null)

    if [ -z "$CONTAINER_NAME" ]; then
        echo "   ⚠️ 无法获取容器名称，跳过"
        ((COUNT_FAILED++))
        continue
    fi

    echo "   容器: $CONTAINER_NAME"

    # 使用 cat + kubectl patch 的方式，避免转义问题
    PATCH_JSON=$(cat <<EOF
{
  "spec": {
    "template": {
      "metadata": {
        "labels": {
          "swck-java-agent-injected": "true"
        },
        "annotations": {
          "sidecar.skywalking.apache.org/initcontainer.Image": "skywalking-java-agent:8.16.0-java8"
        }
      },
      "spec": {
        "containers": [
          {
            "name": "$CONTAINER_NAME",
            "env": [
              {"name": "SW_AGENT_COLLECTOR_BACKEND_SERVICES", "value": "172.28.40.87:11800"},
              {
                "name": "POD_NAMESPACE",
                "valueFrom": {"fieldRef": {"apiVersion": "v1","fieldPath": "metadata.namespace"}}
              },
              {
                "name": "APP_NAME",
                "valueFrom": {"fieldRef": {"apiVersion": "v1","fieldPath": "metadata.labels['app']"}}
              },
              {
                "name": "SW_AGENT_INSTANCE_NAME",
                "valueFrom": {"fieldRef": {"apiVersion": "v1","fieldPath": "metadata.name"}}
              },
              {
                "name": "SW_AGENT_NAME",
                "value": "\$(POD_NAMESPACE)::\$(APP_NAME)"
              }
            ]
          }
        ]
      }
    }
  }
}
EOF
)

    if kubectl patch deployment "$DEPLOYMENT" -n "$NS" --type='strategic' -p "$PATCH_JSON" > /dev/null 2>&1; then
        echo "   ✅ 注入成功  →  Service Group: ${NS}::${DEPLOYMENT}"
        ((COUNT_SUCCESS++))
    else
        echo "   ❌ 注入失败"
        # 显示详细错误
        kubectl patch deployment "$DEPLOYMENT" -n "$NS" --type='strategic' -p "$PATCH_JSON"
        ((COUNT_FAILED++))
    fi
done

echo "========================================"
echo "🎉 处理完成！ 成功: $COUNT_SUCCESS | 跳过: $COUNT_SKIPPED | 失败: $COUNT_FAILED"
```
