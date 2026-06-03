构建脚本
```shell
docker build -t 172.28.40.87/public/sanfu-openjdk:8-jdk-alpine -f Dockerfile .
```
Dockerfile文件
```shell
FROM openjdk:8-jdk-alpine

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

RUN apk add --no-cache tini

RUN set -ex; \
    apk add --no-cache --virtual .build-deps \
        build-base \
        autoconf \
        automake \
        wget \
        tar; \
    wget -O /tmp/cronolog.tar.gz https://files.cnblogs.com/files/crazyzero/cronolog-1.6.2.tar.gz; \
    mkdir -p /tmp/cronolog; \
    tar xzf /tmp/cronolog.tar.gz -C /tmp/cronolog --strip-components=1; \
    cd /tmp/cronolog; \
    ./configure; \
    make; \
    make install; \
    cd /; \
    rm -rf /tmp/cronolog*; \
    apk del .build-deps; \
    # Verify cronolog installation \
    cronolog --version

# Install runtime dependencies and configure system
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk add --no-cache tzdata logrotate ttf-dejavu fontconfig iproute2 && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    apk del tzdata && \
    echo "* soft nofile 65535" >> /etc/limits && \
    echo "* hard nofile 65535" >> /etc/limits && \
    echo "fs.file-max = 100000" >> /etc/sysctl.conf && \
    rm -rf /var/cache/apk/*

```