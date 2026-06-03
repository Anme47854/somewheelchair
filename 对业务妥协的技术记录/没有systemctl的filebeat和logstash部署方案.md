### 1、filebeat
vi /etc/init.d/filebeat
```csharp
#!/bin/sh

# Custom Paths (修改为您的实际路径)
BEAT_HOME="/opt/logcat/filebeat-8.2.0-linux-x86_64"
BEAT_BIN="$BEAT_HOME/filebeat"
BEAT_CONFIG="$BEAT_HOME/filebeat.yml"
BEAT_PIDFILE="/var/run/filebeat.pid"
BEAT_LOGS="/var/log/filebeat.log"

[ -x "$BEAT_BIN" ] || exit 0

. /etc/rc.d/init.d/functions

start() {
    echo -n "Starting filebeat: "
    daemon --pidfile "$BEAT_PIDFILE" "$BEAT_BIN" -c "$BEAT_CONFIG" -path.home "$BEAT_HOME" >> "$BEAT_LOGS" 2>&1 &
    RETVAL=$?
    [ $RETVAL -eq 0 ] && touch /var/lock/subsys/filebeat
    echo
    return $RETVAL
}

stop() {
    echo -n "Stopping filebeat: "
    killproc -p "$BEAT_PIDFILE" filebeat
    RETVAL=$?
    [ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/filebeat
    echo
    return $RETVAL
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        status -p "$BEAT_PIDFILE" filebeat
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
exit $RETVAL
```


### 2、logstatsh
vi /etc/init/logstash.conf
```csharp
start on runlevel [2345]
stop on runlevel [016]
respawn  # 进程退出后自动重启
chdir /opt/logcat/logstash-8.2.0/bin
exec ./logstash -f /opt/logcat/logstash-8.2.0/conf.d/logstash.conf --config.reload.automatic
```
### 启动
```csharp
start logstash
start filebeat
ps aux | grep -E 'logstash|filebeat'  # 检查进程
```
