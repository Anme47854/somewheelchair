##DBH-EC-NGINX安装记录
##梳理过去安装记录
东门机房ip地址:172.28.150.13（使用新版本）
参考安装:172.28.223.46(nginx1.16)
&emsp;&emsp;&emsp;&emsp; 172.28.221.146(nginx.1.16)

版本问题:由于从CentOS7.2换成了Rocky Linux release 9.4 (Blue Onyx)，使用dnf install opensll时，安装的版本为OpenSSL3.0，而Nginx1.16编译时需要的ENGINE_free这个代码在OpenSSl3.0废弃，因此安装方式推荐如下
~~1、更新nginx版本到1.24(废弃)~~
1、更新nginx版本到1.26
2、安装低版本的OpenSSL(低版本nginx可能存在漏洞，非无法安装新版则不推荐此方案)
3、安装openresty(公司除部分项目，暂时未大面积使用该技术栈)

需要安装模块:
nginx_upstream_check_module（由于年过于久远，建议直接在223.46上提取该模块安装包）
pcre-8.35.tar.gz（由于年过于久远，建议直接在223.46上提取该模块安装包）
openssl-3.0.7(dnf安装的没有静态库，需要自己手动编译，链接下方框)
lua-nginx-module(链接下方框)
ngx_devel_kit(链接下方框)
lua-resty-core(链接下方框)
lua-resty-lrucache(链接下方框)
Luajit(下方单独写一个安装的方式)

部分模块下载链接
```c
https://github.com/vision5/ngx_devel_kit/archive/v0.3.1.tar.gz
https://github.com/openresty/lua-nginx-module/archive/v0.10.13.tar.gz
https://github.com/yaoweibin/nginx_upstream_check_module/archive/master.zip
https://www.openssl.org/source/openssl-3.0.7.tar.gz
https://github.com/openresty/lua-resty-lrucache/tags
https://github.com/openresty/lua-resty-core/tags
```


##安装过程

# LuaJIT下载
安装须知，目前网上有两个git项目，使用下方这个带日期版本的
```c
https://github.com/openresty/luajit2/tags
```
## 1、编译和安装
```c
make && sudo make install PREFIX=/usr/local
```
修改环境变量
```c
sudo vi /etc/profile
```
添加环境变量
```c
export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include/luajit-2.1
```
需要在/etc/ld.so.conf.d文件夹下添加配置文件手动指定路径
```c
echo "/usr/local/lib" | sudo tee -a /etc/ld.so.conf.d/luajit.conf
sudo ldconfig
```


# 安装OPENSSL模块
```shell
#如果编译失败，需要配置openssl静态路径
tar -xzf openssl-3.0.7.tar.gz
cd openssl-3.0.7
./config no-shared --prefix=/usr/local/openssl
make -j$(nproc)
sudo make install
```
如果nginx-1.26的安装方式读取不到openssl模块，需要修改编译文件
```c
参考连接
https://blog.51cto.com/sugarlovecxq/5533760
```
相关操作为
```c
1、修改编译文件配置/etc/nginx-1.26.2/auto/lib/openssl/conf
2、修改CORE_的带$OPENSSL的路径，检查配置路径和本地路径是否相同
```

可能有编译失败的问题，需要安装openssl静态路径
```c
wget https://www.openssl.org/source/openssl-3.0.7.tar.gz
tar -xzf openssl-3.0.7.tar.gz
cd openssl-3.0.7
./config no-shared --prefix=/usr/local/openssl
make -j$(nproc)
sudo make install
```

# nginx-1.26.2安装
修改插件配置
```shell
vi /opt/soft/lua-nginx-module-0.10.27/config
添加
LUAJIT_LIB=/usr/local/lib
LUAJIT_INC=/usr/local/include/luajit-2.1
```

编译指令:
```c
# 安装环境
sudo dnf install zlib zlib-devel -y
sudo dnf install gcc gcc-c++ -y
sudo dnf install openssl openssl-devel -y
sudo dnf install pcre pcre-devel -y
# 安装
cd /opt/nginx-1.26.2
```

```c
sudo ./configure \
    --prefix=/opt/nginx \
    --with-http_stub_status_module \
    --with-http_ssl_module \
    --with-openssl=/usr/local/openssl \
    --with-ld-opt=-Wl,-rpath,/usr/local/bin \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_v2_module \
    --with-stream \
    --with-stream_ssl_module \
    --add-module=/opt/soft/ngx_devel_kit-0.3.1 \
    --add-module=/opt/soft/lua-nginx-module-0.10.27 \
    --add-module=/opt/soft/nginx_upstream_check_module-master
	
sudo ./configure
--prefix=/opt/nginx \
--with-http_stub_status_module \
--with-http_ssl_module \
--with-openssl=/usr/local/openssl \
--with-cc-opt="-I/usr/local/include/luajit-2.1" \
--with-ld-opt="-L/usr/local/lib -Wl,-rpath,/usr/local/lib" \
--with-http_gzip_static_module \
--with-http_realip_module \
--with-http_v2_module \
--with-stream \
--with-stream_ssl_module \
--add-module=/opt/soft/ngx_devel_kit-0.3.1 \
--add-module=/opt/soft/lua-nginx-module-0.10.28 \
--add-module=/opt/soft/nginx_upstream_check_module-master
```

```c
sudo make
sudo make install
```

**此时安装完启动报错，提示缺少库文件，则需要安装如下文件**
安装lua-resty-core和lua-resty-lrucache
```c
cd /tmp/lua-resty-core-0.1.29
make install PREFIX=/app/server/nginx/build
cd /tmp/lua-resty-lrucache-0.14
make install PREFIX=/app/server/nginx/build
```
安装完后在conf/nginx.conf
```c
http{

*****
	//http处随便一个地方添加lua-resty-core和lua-resty-lrucache的安装路径
	lua_package_path "/app/server/nginx/build/lib/lua/?.lua;;";

*****
}
```
启动
```c
sudo /opt/nginx/sbin/nginx
```

差异点记录
172.28.223.46
ulimit -n为95535，nginx.conf配置文件为102400

原目录在/opt/mnginx/html
要用ln -s /opt/nginx /opt/mnginx做软连接