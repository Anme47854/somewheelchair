**Kubernetes 创建一个 Pod 的主要流程**
1、用户通过 kubectl 命名发起请求。
2、apiserver 通过对应的 kubeconfig 进行认证，认证通过后将 yaml 中的 Pod 信息存到 etcd。
3、Controller-Manager 通过 apiserver 的 watch 接口发现了 Pod 信息的更新，执行该资源所依赖的拓扑结构整合，整合后将对应的信息交给 apiserver，apiserver 写到 etcd，此时 Pod 已经可以被调度了。
4、Scheduler 同样通过 apiserver 的 watch 接口更新到 Pod 可以被调度，通过算法给 Pod 分配节点，并将 pod 和对应节点绑定的信息交给 apiserver，apiserver 写到 etcd，然后将 Pod 交给 kubelet。
5、kubelet 收到 Pod 后，调用 CNI 接口给 Pod 创建 Pod 网络，调用 CRI 接口去启动容器，调用 CSI 进行存储卷的挂载。
6、网络，容器，存储创建完成后 Pod 创建完成，等业务进程启动后，Pod 运行成功。


**Kubernetes 中 Pod 的重启策略?**
Pod 重启策略（RestartPolicy）应用于 Pod 内的所有容器，并且仅在 Pod 所处的 Node 上由 kubelet 进行判断和重启操作。
当某个容器异常退出或者健康检查失败时，kubelet 将根据 RestartPolicy 的设置来进行相应操作。Pod 的重启策略包括 Always、OnFailure 和 Never，默认值为 Always。
Always：当容器失效时，由 kubelet 自动重启该容器；
OnFailure：当容器终止运行且退出码不为 0 时，由 kubelet 自动重启该容器；
Never：不论容器运行状态如何，kubelet 都不会重启该容器。
同时 Pod 的重启策略与控制方式关联，当前可用于管理 Pod 的控制器包括 ReplicationController、Job、DaemonSet 及直接管理 kubelet 管理（静态 Pod）。 
不同控制器的重启策略限制如下：
RC 和 DaemonSet：必须设置为 Always，需要保证该容器持续运行；
Job：OnFailure 或 Never，确保容器执行完成后不再重启；
kubelet：在 Pod 失效时重启，不论将 RestartPolicy 设置为何值，也不会对 Pod 进行健康检查。

**Kubernetes中Pod的健康检查方式**
对 Pod 的健康检查可以通过两类探针来检查：
LivenessProbe 和 ReadinessProbe。
LivenessProbe 探针：用于判断容器是否存活（running 状态），如果 LivenessProbe 探针探测到容器不健康，则 kubelet 将杀掉该容器，并根据容器的重启策略做相应处理。若一个容器不包含 LivenessProbe 探针，kubelet 认为该容器的 LivenessProbe 探针返回值于是 “Success”。
ReadinessProbe 探针：用于判断容器是否启动完成（ready 状态）。如果 ReadinessProbe 探针探测到失败，则 Pod 的状态将被修改。Endpoint Controller 将从 Service 的 Endpoint 中删除包含该容器所在 Pod 的 Endpoint。
startupProbe 探针：启动检查机制，应用一些启动缓慢的业务，避免业务长时间启动而被上面两类探针 kill 掉。

**Kubernetes Pod 的 LivenessProbe 探针的常见方式**
kubelet 定期执行 LivenessProbe 探针来诊断容器的健康状态，通常有以下三种方式：
ExecAction：在容器内执行一个命令，若返回码为 0，则表明容器健康。
TCPSocketAction：通过容器的 IP 地址和端口号执行 TCP 检查，若能建立 TCP 连接，则表明容器健康。
HTTPGetAction：通过容器的 IP 地址、端口号及路径调用 HTTP Get 方法，若响应的状态码大于等于 200 且小于 400，则表明容器健康。

**策略为Always：当容器失效时，由 kubelet 自动重启该容器； 那你觉得多久会自动重启。**
重启不是立即的，而是采用指数退避策略。首次延迟通常是 10 秒，随后按 10s、20s、40s 翻倍，直到达到最大延迟 300秒（5分钟）。当然，如果容器成功运行超过 10 分钟，这个计时器会被重置。

**Kubernetes 的调度机制**
Kubernetes 调度由 kube-scheduler 组件完成，核心目标是为新建 Pod 选择最合适的节点。 调度分为预选和优选两步：
预选（Predicates）：过滤掉不满足条件的节点，如资源不足、端口冲突、节点亲和性不匹配等。
优选（Priorities）：对通过预选的节点打分，优先选择分数最高的节点，平衡资源利用率。 
此外，还支持节点亲和性/反亲和性、Pod 亲和性/反亲和性、污点与容忍度等高级调度策略，满足复杂的业务部署需求。

**Kubernetes Service 类型**
通过创建Service，可以为一组具有相同功能的容器应用提供一个统一的入口地址，并且将请求负载分发到后端的各个容器应用上。
其主要类型有：
ClusterIP：虚拟的服务 IP 地址，该地址用于 Kubernetes 集群内部的 Pod 访问，在 Node 上 kube-proxy 通过设置的 iptables 规则进行转发；
NodePort：使用宿主机的端口，使能够访问各 Node 的外部客户端通过 Node 的 IP 地址和端口号就能访问服务；
LoadBalancer：使用外接负载均衡器完成到服务的负载分发，需要在 spec.status.loadBalancer 字段指定外部负载均衡器的 IP 地址，通常用于公有云。

**Kubernetes 外部如何访问集群内的服务**
对于 Kubernetes，集群外的客户端默认情况，无法通过 Pod 的 IP 地址或者 Service 的虚拟 IP地址:虚拟端口号进行访问。
通常可以通过以下方式进行访问 Kubernetes 集群内的服务：
映射 Pod 到物理机：将 Pod 端口号映射到宿主机，即在 Pod 中采用 hostPort 方式，以使客户端应用能够通过物理机访问容器应用。
映射 Service 到物理机：将 Service 端口号映射到宿主机，即在 Service 中采用 nodePort 方式，以使客户端应用能够通过物理机访问容器应用。
映射 Service 到 LoadBalancer：通过设置 LoadBalancer 映射到云服务商提供的 LoadBalancer 地址。这种用法仅用于在公有云服务提供商的云平台上设置 Service 的场景。

**Kubernetes 中 Namespace 的作用？**
Namespace 是 Kubernetes 集群内的逻辑隔离单位，主要作用包括：
实现多租户隔离，不同团队或业务可在同一集群中使用独立的 Namespace，资源互不干扰；
支持资源配额管理，可为每个 Namespace 限制 CPU、内存等资源使用量；
便于权限控制，可针对 Namespace 配置 RBAC 权限，实现精细化访问管理。

**Kubernetes 中 Labels 与 Selector 的作用？**
Labels 是附加在 Kubernetes 资源上的键值对标签，用于标识资源属性；
Selector 则通过匹配 Labels 筛选出目标资源。
它们的核心作用是实现资源的动态关联与管理，例如Service 通过 Selector 匹配后端 Pod、Deployment 通过 Selector 管理 ReplicaSet，实现解耦和灵活调度。

**Kubernetes 中 Deployment 的作用？**
Deployment 是 Kubernetes 中最常用的无状态应用控制器，主要作用包括：
管理 Pod 的创建与扩缩容，支持滚动更新与回滚；
定义 Pod 的期望状态，通过 ReplicaSet 保证副本数稳定；
支持灰度发布、暂停/恢复更新，降低发布风险，保障应用持续可用。

**Kubernetes 中 Ingress 的作用？**
Ingress 是 Kubernetes 集群内的 HTTP/HTTPS 流量入口，它通过域名、路径等规则将外部请求转发到对应的 Service，实现统一的负载均衡、SSL 终止和域名路由。
Ingress 本身需要配合 Ingress Controller（如 Nginx Ingress）使用，是生产环境中对外暴露服务的主流方式。

**Kubernetes 中 PV 与 PVC 的关系？**
PV（PersistentVolume）是集群中的存储资源，由管理员预先创建；
PVC（PersistentVolumeClaim）是用户对存储资源的申请。
用户通过 PVC 声明存储需求，Kubernetes 会根据 PVC 的请求（容量、访问模式等）自动匹配合适的 PV，绑定后供 Pod 挂载使用，实现存储与计算的解耦。

**Kubernetes 中 ConfigMap 与 Secret 的区别？**
ConfigMap 用于存储非敏感配置数据（如配置文件、环境变量），数据以明文形式存储；
Secret 用于存储敏感数据（如密码、密钥、证书），数据以 Base64 编码存储（部分场景支持加密存储）。
二者都可通过环境变量、配置文件挂载的方式注入到 Pod 中，实现配置与镜像的解耦。

**K8s中污点和容忍度分别是什么？有什么作用？**
污点是打在节点上的键值对，用于排斥特定 Pod 调度到该节点；
容忍度配置在 Pod 上，用来匹配节点污点，允许 Pod 调度至带污点的节点。
常用于节点独占、特殊业务隔离、master 节点禁止普通业务部署等场景。

**K8s什么是滚动更新？优势是什么？**
滚动更新是 Deployment 默认的发布策略，逐步销毁旧版本 Pod、同时创建新版本Pod，分批替换。
无需停机、业务不中断，更新过程平稳，出现问题可快速执行回滚，极大提升线上服务稳定性。

**K8s资源限制 request 与 limit 区别**
request 是Pod申请的最小资源，用于集群调度分配节点；
limit 是Pod最大可用资源，防止容器超占资源。
request 决定调度，limit 限制峰值，合理配置可保证集群资源合理分配与稳定运行。

**K8s 中 kube-proxy 的三种模式及原理差异？**
kube-proxy 负责实现 Service 到 Pod 的流量转发，三种模式原理差异如下：
userspace 模式：早期方案，用户态进程监听 Service 端口，转发请求到后端 Pod，性能差，已基本淘汰。
iptables 模式：默认模式，通过内核 iptables 规则实现流量转发，无用户态中转，性能高，但规则量大时会影响转发效率。
ipvs模式：基于内核IPVS实现负载均衡，支持多种调度算法，性能远高于iptables，适合大规模集群，是高并发场景的首选方案。

**K8s 中 Pod 调度失败的常见原因及排查思路？**
Pod 调度失败通常由以下原因导致：
资源不足：节点 CPU/内存剩余量无法满足 Pod 的 request 申请。
节点亲和性/反亲和性规则不匹配：Pod 的调度策略与节点标签或其他 Pod 分布冲突。
污点与容忍度不匹配：节点存在污点，而 Pod 未配置对应的容忍度。
端口冲突：节点上已占用 Pod 声明的 hostPort 或 NodePort。 
排查思路：通过 kubectl describe pod 查看事件信息，结合 kubectl describe node 检查节点资源与标签，逐步定位问题。	

**K8s 中 StatefulSet 与 Deployment 的核心区别及适用场景？**
二者核心区别在于是否提供稳定的网络标识和有序部署/扩缩容能力：
Deployment：面向无状态应用，Pod 无固定身份，IP 变化不影响服务，适用于 Web 服务、API 等场景。
StatefulSet：面向有状态应用，提供稳定的 Pod 主机名和 DNS 域名，支持有序部署、扩缩容和滚动更新，适用于数据库、消息队列、分布式存储等需要持久化状态的场景。

**K8s容器逃逸常见风险与基础防护手段**
容器本质上共享宿主机内核，一旦隔离被突破就可能实现逃逸，这是其核心安全隐患。
常见风险包括：使用 privileged 特权容器（拥有接近宿主机 root 权限）、挂载宿主机敏感目录（如 /var/run/docker.sock、/proc、/ 等）、容器运行内核存在漏洞、赋予过多 Linux capabilities（如 SYS_ADMIN）。
基础防护手段包括：禁止使用 privileged 模式、按最小权限原则裁剪 capabilities、严格限制 hostPath 挂载、容器使用非 root 用户运行、配置 securityContext（如只读根文件系统、禁止提权）、结合网络策略（NetworkPolicy）限制容器间横向访问，从多层面降低逃逸风险。

**K8s 大规模集群下，iptables 模式性能瓶颈是什么，如何优化**
在大规模集群中，随着 Service 和 Endpoint 数量增加，iptables 规则数量会急剧膨胀，且其匹配机制为线性遍历，导致转发延迟上升、CPU 开销增大，成为网络性能瓶颈。优化方式主要是将 kube-proxy 从 iptables 模式切换为 IPVS 模式，利用内核级哈希表实现高效转发，支持多种负载均衡算法（如 rr、lc 等），性能更优。
同时可通过清理无用 Service、控制集群资源规模、合理拆分业务命名空间等手段减少规则数量，从而进一步提升整体网络性能。

**K8s Informer(监控api变化并通知用户)机制的核心原理**
Informer 是 Kubernetes 控制器中用于高效感知资源变化的核心机制，基于 List + Watch 模型实现。
其流程是：首先通过 Reflector 向 apiserver 发起全量 List 获取资源数据，并建立 Watch 长连接持续监听变更；
变更事件进入 DeltaFIFO 队列进行缓冲与去重，同时写入本地缓存 Indexer，控制器优先从缓存读取资源，减少对 apiserver 的直接访问；
Informer 支持注册 Add/Update/Delete 事件回调，控制器通常在回调中将对象放入自身的 WorkQueue，再进行异步调谐（reconcile）。
通过“缓存 + 增量更新 + 事件驱动”的方式，实现高效、低延迟地管理集群资源。

**K8s 中 etcd 为什么重要？生产环境如何保障 etcd 高可用与数据安全？**
etcd 是 Kubernetes 的核心数据存储，集群中的节点信息、Pod、Deployment、Secret、ConfigMap 等所有核心状态数据都存储在 etcd 中，本质上相当于整个 K8s 集群的“大脑”。一旦 etcd 异常，轻则资源无法更新，重则整个集群不可用。
生产环境保障 etcd 高可用与数据安全，通常从以下几个方面入手：采用奇数节点集群部署（如 3 节点或 5 节点），基于 Raft 协议实现数据一致性与故障容错etcd 节点尽量独立部署，避免与高负载业务混跑定期做快照备份，同时进行异地备份，防止误删或磁盘损坏磁盘必须使用高性能 SSD，因为 etcd 对磁盘 IO 延迟极其敏感开启 TLS 双向认证，避免未授权访问 etcd 数据监控关键指标，如 leader 变化、磁盘延迟、db size、请求耗时等避免频繁大规模写入 ConfigMap、事件风暴等行为冲击 etcd
性能本质上：K8s 的稳定性，很大程度上取决于 etcd 的稳定性。

**为什么生产环境不建议直接使用 Docker，而逐渐转向 containerd？**
Docker 本身不仅仅是容器运行时，还包含镜像构建、CLI、API 等完整工具链，而 Kubernetes 真正需要的其实只是“运行容器”的能力。早期 K8s 通过 dockershim 对接 Docker，但随着 Kubernetes 演进，社区逐渐废弃 dockershim，转向符合 CRI（Container Runtime Interface）标准的 containerd、CRI-O 等运行时。
containerd相比Docker的优势主要有：架构更轻量，专注容器运行，组件更少资源占用更低，减少额外守护进程开销与 K8s 原生集成更好，直接兼容 CRI稳定性更高，减少 Docker 层带来的复杂问题Docker 实际底层本来也依赖 containerd 运行容器
但需要注意：Docker CLI 使用体验更友好containerd 更偏底层运维，需要使用 ctr、crictl、nerdctl 等工具管理所以现在很多生产环境的趋势是： “开发阶段用 Docker，K8s 运行阶段用 containerd。”

**K8s 中为什么会出现脑裂（Split Brain）问题？如何避免？**
脑裂本质是集群中的节点因为网络分区或通信异常，导致多个节点都认为自己是“主节点”，从而产生数据不一致问题。在 Kubernetes 中，脑裂问题最典型体现在：etcd 集群数据库主从集群Redis Sentinel自研 HA 系统以 etcd 为例，如果网络发生分区：一部分节点失去通信少数派节点可能无法正常选举 leader如果配置不合理，可能出现多个节点同时提供写服务，引发数据冲突K8s 避免脑裂的核心手段包括：基于 Raft 一致性协议，只有多数派节点才能对外提供写服务etcd 必须使用 奇数节点部署（3、5、7），避免平票节点间网络必须稳定低延迟配置合理的心跳与选举超时时间对存储与网络做高可用设计，避免频繁网络抖动对业务层增加 fencing（隔离机制），避免双主同时写入核心思想是： 宁可短暂不可写，也绝不允许数据不一致。

**K8s 中为什么不建议直接使用 hostPath？它有哪些风险？**
hostPath允许Pod直接挂载宿主机目录，虽然使用方便，但在生产环境中属于高风险能力。
其核心风险包括：
破坏容器隔离性：容器可直接访问宿主机文件系统，存在容器逃逸风险
影响节点安全：如果挂载了 /、/var/run/docker.sock 等敏感目录，容器甚至可能控制宿主机Pod 可迁移性差：hostPath 强依赖节点本地目录，Pod 调度到其他节点后可能无法运行
数据一致性问题：多个 Pod 同时操作宿主机目录，容易产生脏数据或覆盖问题
节点耦合严重：不利于 K8s 的弹性调度与自动恢复
生产环境更推荐：
使用 PVC + StorageClass 动态存储使用 NFS、Ceph、云盘等统一存储方案必须使用 hostPath 时，严格限制目录范围与读写权限
hostPath 本质是“绕过 K8s 存储抽象”，会削弱云原生平台的隔离与调度能力。

**K8s 中 Deployment 为什么不能直接用于有状态服务**
Deployment 主要用于无状态应用，其设计目标是 Pod可随时销毁、重建、漂移，因此并不适合强依赖“身份”和“数据”的有状态服务。
有状态服务通常包括：
MySQL
Redis
Kafka
Elasticsearch
这些服务通常要求：
固定网络
身份固定
存储绑定
有序启动与停止数据持久化
而 Deployment 的问题在于：
Pod 名称随机变化
Pod 重建后 IP 会变化
不保证启动顺序
存储绑定能力较弱
因此 Kubernetes 提供了 StatefulSet：
Pod 名称固定（如 mysql-0、mysql-1）
支持稳定网络标识
支持 PVC 一一绑定支持有序扩缩容与滚动更新
所以： Deployment 适合“随时可替换”的服务，而 StatefulSet 才适合“有身份、有数据”的服务。

**K8s中为什么会出现雪崩效应？如何避免？**
雪崩效应指的是集群中某个服务故障后，引发连锁反应，最终导致整个系统大量服务不可用。
在 Kubernetes 中，常见场景包括：
某个核心服务异常，导致大量上游请求堆积
Pod 大量 OOM 或重启
数据库连接池被打满
节点故障导致大量 Pod 同时迁移
探针配置不合理，引发批量重启
雪崩通常具有“放大效应”： 一个小故障，最终拖垮整个集群。
常见防护手段包括：
服务限流与熔断，避免异常流量继续扩散
合理设置资源 requests/limits，防止资源争抢
增加 HPA/VPA 自动扩缩容能力
Pod 分散部署，避免业务集中在单节点
使用 PDB（PodDisruptionBudget）防止业务一次性全部驱逐
合理设置 livenessProbe 与 readinessProbe，避免误杀
核心依赖（数据库、缓存）必须高可用建立完善监控与告警体系，提前发现异常
核心： 稳定性治理的核心，不只是“防故障”，而是“防故障扩散”。