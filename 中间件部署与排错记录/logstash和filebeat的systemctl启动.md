### 1、logstash
创建一个/usr/local/logstash-8.2.0/logstash.d文件夹
```csharp
mkdir -p /usr/local/logstash-8.2.0/logstash.d
cp /opt/logcat/logstash-8.2.0/conf.d/*.conf /usr/local/logstash-8.2.0/logstash.d
```
修改logcat/logstash-8.2.0/config/startup.options里的，别用root
LS_OPTS
LS_USER
LS_GROUP
```csharp
#添加刚刚创建的文件夹地址--path.config /usr/local/logstash-8.2.0/logstash.d
LS_OPTS="--path.settings ${LS_SETTINGS_DIR} --path.config /usr/local/logstash-8.2.0/logstash.d"
# user and group id to be invoked as
LS_USER=root
LS_GROUP=root
```
使用应用自带的安装器添加
```csharp
./logstash-8.2.0/bin/system-install
```
systemctl enable logstash.service
systemctl start logstash

### 2、filebeat
vi /etc/systemd/system/filebeat.service
叫你别用root，你迩夺龙了吗
```csharp
[Unit]
Description=Filebeat Service
Documentation=/opt/logcat/filebeat-8.2.0-linux-x86_64 -help
Wants=network-online.target
After=network-online.target

[Service]
User=root
Environment="BEAT_CONFIG_OPTS=-c /opt/logcat/filebeat-8.2.0-linux-x86_64/filebeat.yml"
ExecStart=/opt/logcat/filebeat-8.2.0-linux-x86_64/filebeat -e -c /opt/logcat/filebeat-8.2.0-linux-x86_64/filebeat.yml
Restart=always

[Install]
WantedBy=multi-user.target
```
sudo systemctl daemon-reload

sudo systemctl enable filebeat.service
sudo systemctl start filebeat.service
