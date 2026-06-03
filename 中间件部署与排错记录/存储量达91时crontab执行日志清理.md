传输方案
```shell
#避免连接过久，增加一个超过三十秒
ansible all -i /etc/ansible/hosts -m synchronize -a "src=/opt/del_logs_91.sh dest=/opt/soft/" -u {此处使用非root用户名} -e "ANSIBLE_TIMEOUT=30"
```
crontab添加
```shell
ansible all -i /etc/ansible/hosts -m cron -a "user={此处使用非root用户名} name='Delete logs every 8 minutes' minute=*/8 job='sh /opt/soft/del_logs_91.sh'"
```

脚本如下
```shell
#!/bin/bash

# 获取 /opt/ 目录的使用百分比
usage=$(df -h /opt/ | awk 'NR==2 {print $5}' | sed 's/%//')

# 如果使用率达到 90% 或更高，执行日志清理
if [ "$usage" -ge 90 ]; then
    echo "/opt 使用率达到 $usage%，开始清理日志..."

    # 如果使用率超过95%，执行更激进的清理策略
    if [ "$usage" -ge 95 ]; then
        echo "警告：/opt 使用率超过95%，执行紧急清理！"
        
        # 清理所有以 {应用名称} 开头的目录中的 logs 文件夹内容
        for dir in /opt/{应用名称}*/logs/; do
            if [ -d "$dir" ]; then
                echo "紧急清理 $dir 下的所有日志..."
                find "$dir" -type f -exec rm -f {} \;
            fi
        done
    else
        # 普通清理模式（90%-94%）
        # 清理所有以 {应用前缀} 开头的目录中60分钟前的日志        
        for dir in /opt/{应用前缀}*/logs/; do
            if [ -d "$dir" ]; then
                echo "清理 $dir 下60分钟前的日志..."
                find "$dir" -mmin +60 -type f -exec rm -f {} \;
                # 如果觉得60分钟太近可以选择这个清理24小时前的日志
                # find "$dir" -mtime +0 -type f -exec rm -f {} \;
                # 24小时还是近，就选这个七天前
                # find "$dir" -mtime +7 -type f -exec rm -f {} \;
            fi
        done
    fi

    # 比较通用的tomcat 判断并清理 /opt/tomcat/*/logs/ 下的日志
    if [ -d "/opt/tomcat/*/logs/" ]; then
        echo "清理 /opt/tomcat/*/logs/ 下的日志..."
        find /opt/tomcat/*/logs/ -mtime +7 -type f -exec rm -f {} \;
    fi

    # 判断并清理 /opt/applogs/xxl-job/jobhandler 下的日志
    if [ -d "/opt/applogs/xxl-job/jobhandler/" ]; then
        echo "清理 /opt/applogs/xxl-job/jobhandler 下的日志..."
        find /opt/applogs/xxl-job/jobhandler/ -mtime +7 -type f -exec rm -f {} \;
    fi

    # 判断并清理 /opt/sentinel 下的日志
    for dir in /opt/sentinel/{应用前缀}*/logs/; do
        if [ -d "$dir" ]; then
            echo "清理 $dir 下的日志..."
            find "$dir" -mtime +3 -type f -exec rm -f {} \;
        fi
    done

    # 新增：清理 NGINX 日志并重载配置
    # 检查 /opt/nginx/logs/ 目录
    # 这边的目录其实还是需要根据nginx.conf来配置，
    # ai推荐logrotate，这个以后再弄
    if [ -d "/opt/nginx/logs/" ]; then
        echo "清理 /opt/nginx/logs/ 下的 .log 文件..."
        find /opt/nginx/logs/ -name "*.log" -mtime +0 -type f -exec rm -f {} \;

        # 重载 NGINX 配置
        if [ -x "/opt/nginx/sbin/nginx" ]; then
            echo "重载 /opt/nginx 配置..."
            sudo /opt/nginx/sbin/nginx -s reload
        fi
    fi

    echo "日志清理完成."
else
    echo "/opt 使用率为 $usage%，不需要清理日志."
fi
```