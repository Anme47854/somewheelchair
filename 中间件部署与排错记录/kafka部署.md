下载页面
```shell
http://kafka.apache.org/downloads.html
```
将文件上传到服务器解压
```shell
tar -zxvf kafka_2.13-3.6.2.tgz
```
修改启动脚本bin/kafka-server-start.sh
```shell
找到
export KAFKA_HEAP_OPTS="-Xmx2G -Xms1G"
修改为(根据机器配置修改)
export KAFKA_HEAP_OPTS="-Xmx4G -Xms2G"
```
修改集群节点配置config/kraft/server.properties相关配置
```shell
process.roles=broker,controller
##不同集群要修改该id
node.id=1

controller.quorum.voters=1@172.28.223.66:9093,2@172.28.223.67:9093,3@172.28.223.68:9093
##不同服务器要修改该ip
listeners=PLAINTEXT://172.28.223.66:9092,CONTROLLER://172.28.223.66:9093,INTERNAL://192.168.223.66:9091
##不同服务器要修改该ip
advertised.listeners=PLAINTEXT://172.28.223.66:9092,INTERNAL://192.168.223.66:9091

controller.listener.names=CONTROLLER

listener.security.protocol.map=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL,INTERNAL:PLAINTEXT

num.network.threads=3

num.io.threads=8

socket.send.buffer.bytes=102400

socket.receive.buffer.bytes=102400

socket.request.max.bytes=104857600

log.dirs=/opt/kafka_2.13-3.6.2/kraft-combined-logs

num.partitions=3

num.recovery.threads.per.data.dir=3

offsets.topic.replication.factor=3
transaction.state.log.replication.factor=3
transaction.state.log.min.isr=2

log.retention.hours=48

log.segment.bytes=1073741824

log.retention.check.interval.ms=300000

```

初始化配置
```shell
bin/kafka-storage.sh format -t 3fZh-maBQem8zxbT8v2D4w -c config/kraft/server.properties
```
启动kafka
```shell
bin/kafka-server-start.sh -daemon config/kraft/server.properties
```