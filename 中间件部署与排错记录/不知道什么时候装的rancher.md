1、找到你的 Rancher 版本所需的资源
资源获取
```shell
https://github.com/rancher/rancher/releases
```

2、收集 cert-manager 镜像（除非你使用自己的证书，或在负载均衡器上终止 TLS）

3、把镜像保存到你的工作站

4、推送镜像到私有镜像仓库

5、安装ingress
```shell
https://blog.csdn.net/lwxvgdv/article/details/139505997?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522e12ac54c769b23b228f9062a8e1ebfec%2522%252C%2522scm%2522%253A%252220140713.130102334.pc%255Fblog.%2522%257D&request_id=e12ac54c769b23b228f9062a8e1ebfec&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~blog~first_rank_ecpm_v1~rank_v31_ecpm-1-139505997-null-null.nonecase&utm_term=lb&spm=1018.2226.3001.4450

https://blog.csdn.net/lwxvgdv/article/details/139505471


```

6、启动rancher
```shell
[root@fs-k8s-manage rainbond]# cat /opt/rancher/docker-compose.yaml 
version: '3'
services:
  rancher:
    restart: always
    privileged: true
    image: sfharbordev.sanfu.com/rancher/rancher:v2.8.4
    container_name: rancher
    volumes:
      - /opt/rancher/data:/var/lib/rancher
      - /etc/resolved.conf:/etc/resolved.conf
    environment:
      - TZ=Asia/Shanghai
      - CATTLE_BOOTSTRAP_PASSWORD=admin
    ports:
      - 8080:80
      - 1443:443
    networks:
      - bigdata
networks:
  bigdata:
    external: true
```
