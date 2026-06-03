问题记录
同事当天晚上需要进行重启redis调整redis配置以减小redis内存maxmemory7G→maxmemory6G

每台重启间隔10分钟

1.发现redis某节点启动过程中多次内存超出后下降，查看redis日志后怀疑是AOF过程过于频繁导致，发现配置没有开启混合持久化

```
# 开启混合持久化
aof-use-rdb-preamble yes

# 设置复制积压缓冲区（避免全量同步）
repl-backlog-size 256mb

# 适当增大集群超时（避免启动期间被误判下线）
cluster-node-timeout 30000

# 确保从节点在加载期间仍可读（缓解连接堆积）
slave-serve-stale-data yes
```

2.grafana数据采集不完整，可能是因为redis正在进行大量数据同步，怀疑性能瓶颈

3.日志中发现redis因为性能瓶颈自行关闭，导致51分后监控无数据

4.想到aof数据同步时会需要内存，导致可能内存不足，临时修改内存大小后，发现并无作用

5.观察clients与auth的关系，发现机器重启时auth数激增，这可能导致此时redis性能受损，导致卡顿

6.重启redis后观察redis连接数暴涨，临时调整client连接数，发现修改maxclients 40000配置后

判断是：重启后客户端连接数激增，导致 Redis 主线程被大量命令（尤其是 AUTH）阻塞，叠加 AOF 重写和全量同步的磁盘 IO 压力，最终引发性能崩溃。