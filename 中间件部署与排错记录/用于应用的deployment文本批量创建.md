1、先根据应用名称创建文件夹
2、使用CopyFileToAllDir.sh将temp.yaml拷贝到当前文件夹下的应用名文件夹
3、使用ReplaceName.sh重命名temp为文件夹目录名称
4、执行Updateyaml.sh，修改里面的$job_name、$job_space、$job_port参数

temp.yaml
#这个temp特别说明，理论上需要用到limits和request去做pod容器的资源限制，如果测试环境可以写死，反正用不到那么高，还能节省资源出来
```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: $job_name
  namespace: $job_space
  labels:
    app: $job_name
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $job_name
  template:
    metadata:
      labels:
        app: $job_name
    spec:
      volumes:
        - name: host-time
          hostPath:
            path: /etc/localtime
            type: ''
      containers:
        - name: $job_name
          image: '$job_name:1.0.0'
          ports:
            - name: http-$job_port
              containerPort: $job_port
              protocol: TCP
          env:
            #这里有两种，第一个是固定jvm值，第二种被注释的是开启容器感知，做百分比，百分比有个好处是内存达到一定值后可以自动扩容
            - name: JAVA_TOOL_OPTIONS
              value: "-Xmx512m -Xms512m"
              #value:  -XX:MaxRAMPercentage=50.0 -XX:InitialRAMPercentage=50.0 -XX:+UseContainerSupport
          resources: 
            limits:
              memory: 1Gi
            requests:
              memory: 1Gi
          volumeMounts:
            - name: host-time
              readOnly: true
              mountPath: /etc/localtime
          readinessProbe:
            httpGet:
              path: /actuator/health
              port: $job_port
              scheme: HTTP
            initialDelaySeconds: 20
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          startupProbe:
            httpGet:
              path: /actuator/health
              port: $job_port
              scheme: HTTP
            initialDelaySeconds: 40
            timeoutSeconds: 3
            periodSeconds: 20
            successThreshold: 1
            failureThreshold: 10
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: Always
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      serviceAccountName: default
      securityContext: {}
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 0%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
```
hpa对这个的自动扩容hpa，可以根据自己需要添加
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: $job_name-hpa
  namespace: $job_space  
spec:
  scaleTargetRef:  # 监控哪些deploy
    apiVersion: apps/v1
    kind: Deployment 
    name: $job_name  # deploy的name
  minReplicas: 1  # 最小pod数量，不能小于deploy的副本数
  maxReplicas: 5  # 最大pod数量
  metrics:  # 定义伸缩的规则
  - type: Resource  # 类型是资源 
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 90  # 内存使用率达到90%时触发扩容
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80  # CPU达到80%也可触发扩容        
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 缩容稳定窗口5分钟
      policies:
      - type: Percent
        value: 50  # 每次最多缩容50%的副本
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # 扩容无稳定窗口，立即响应
      policies:
      - type: Percent
        value: 100  # 每次最多扩容100%的副本
        periodSeconds: 15  # 每15秒检查一次
      - type: Pods
        value: 4  # 或每次最多增加4个Pod
        periodSeconds: 15
      selectPolicy: Max  # 选择较大的变更幅度
```
执行
CopyFileToAllDir.sh拷贝temp文件
```shell
#!/bin/bash

# 源文件路径
SOURCE_FILE="/opt/soft/Deployment/temp.yaml"

# 使用通配符匹配所有子目录中的ms-sanfu开头文件夹
for dir in */*; do
  # 检查是否是一个目录
  if [ -d "$dir" ]; then
    # 拷贝源文件到目标文件夹
    cp "$SOURCE_FILE" "$dir"
    echo "Copied $SOURCE_FILE to $dir"
  fi
done
```
执行ReplaceName.sh
```shell
#!/bin/bash

# 查找所有包含temp.yaml文件的文件夹
find . -path "*/*/temp.yaml" | while read -r file_path; do
  # 获取文件所在目录
  dir_path=$(dirname "$file_path")
  # 获取文件夹名称（去掉路径部分）
  folder_name=$(basename "$dir_path")
  # 生成目标文件名
  target_file="${folder_name}.yaml"
  # 重命名文件
  mv "$file_path" "$dir_path/$target_file"
  echo "Renamed $file_path to $dir_path/$target_file"
done
```
执行参数替换
sh Updateyaml.sh
```shell
#!/bin/bash

# 定义端口映射（从您提供的数据中提取）
declare -A port_mapping=(
    ["xxx1"]="10011"
    ["xxx2"]="10012"
    ["xxx3"]="10013"
)

# 查找所有temp.YAML文件
find . -name "*.yaml" -path "*/*" | while read -r yaml_file; do
    # 获取文件名（不含路径和扩展名）
    filename=$(basename "$yaml_file" .yaml)
    
    # 获取端口
    job_port="${port_mapping[$filename]}"
    
    # 获取命名空间（特殊处理ms-sanfu-trace）
    if [ "$filename" = "ms-sanfu-trace" ]; then
        job_space="component"
    else
        # 提取ms-sanfu-后面的部分作为命名空间
        job_space=$(echo "$filename" | sed 's/^ms-sanfu-//')
        # 如果包含连字符，取第一个连字符前的部分
        job_space=$(echo "$job_space" | cut -d'-' -f1)
    fi
    
    echo "Processing: $filename"
    echo "  Port: $job_port"
    echo "  Namespace: $job_space"
    
    # 使用sed命令替换YAML文件中的参数
    # 注意：这里假设YAML文件中有 $job_name、$job_space、$job_port 这三个变量需要替换
    sed -i \
        -e "s/\$job_name/$filename/g" \
        -e "s/\$job_space/$job_space/g" \
        -e "s/\$job_port/$job_port/g" \
        "$yaml_file"
    
    echo "  Updated: $yaml_file"
    echo "----------------------------------------"
done

echo "All YAML files have been updated successfully!"
```