获取安装包
```shell
wget http://download.redis.io/releases/redis-4.0.14.tar.gz
wget https://cache.ruby-lang.org/pub/ruby/2.3/ruby-2.3.1.tar.gz

```
配置系统参数
```shell
sudo sh -c "echo 'vm.overcommit_memory = 1' >> /etc/security/limits.conf "
sudo sh -c "echo 'net.core.somaxconn= 1024' >> /etc/security/limits.conf "
sudo sh -c "echo '* soft nofile 65536' >>  /etc/security/limits.d/20-nproc.conf"
sudo sh -c "echo '* hard nofile 65536' >>  /etc/security/limits.d/20-nproc.conf"
sudo sh -c "echo '* soft nproc 65536 ' >>  /etc/security/limits.d/20-nproc.conf"
sudo sh -c "echo '* hard nproc 65536 ' >>  /etc/security/limits.d/20-nproc.conf"
sudo sh -c "echo 'vm.max_map_count = 655360' >> /etc/security/limits.conf "
sudo sysctl -p
```
安装必要软件和创建文件夹
```shell
sudo yum install zlib-devel -y
sudo yum install openssl-devel -y
sudo mkdir -pv /opt/redis_data
sudo mkdir -pv /usr/local/redis/cluster 
```
安装redis-4.0.14
```shell
cd /opt/redis-4.0.14
sudo make  -j 4 && sudo make  install -j 4
```
安装ruby
```shell
tar -xvf ruby-2.3.1.tar.gz
cd /opt/ruby-2.3.1.tar.gz
sudo ./configure -prefix=/usr/local/ruby
sudo make -j 4 && sudo  make -j 4 install
sudo vim /etc/profile.d/ruby.sh
//ruby.sh文件内容如下
RUBY_HOME='/usr/local/ruby'
PATH=$PATH:$RUBY_HOME/bin
export RUBY_HOME PATH
#############################
//上述保存完后执行
source /etc/profile.d/ruby.sh
```
安装Ruby gem
```shell
cd /opt/redis
sudo env PATH=$PATH gem install redis -v 4.1.2
```

```shell
sudo cp /opt/soft/redis-4.0.14/src/redis-trib.rb /usr/bin/
```
快捷修改配置内容
```shell
:%s/8001/9002/g
```

启动redis
```shell
sudo /opt/redis-4.0.14/src/redis-server /usr/local/redis/cluster/redis_9003.conf
```

两种创建集群
```shell
redis-cli --cluster create 172.28.188.11:8001  172.28.188.11:9001 172.28.160.19:8002 172.28.160.19:9002 172.28.188.14:8003 172.28.188.14:9003 --cluster-replicas 1

sudo ruby /opt/redis-4.0.14/src/redis-trib.rb create --replicas 1 172.28.188.11:8001 172.28.188.11:9001 172.28.160.19:8002 172.28.160.19:9002 172.28.188.14:8003 172.28.188.14:9003
```

