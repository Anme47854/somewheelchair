默认安装方式安装报
### 报错一、certificate verify failed
```csharp
[root@x bin]# ./logstash-plugin install logstash-input-http
Using bundled JDK: /opt/logcat/logstash-8.2.0/jdk
OpenJDK 64-Bit Server VM warning: Option UseConcMarkSweepGC was deprecated in version 9.0 and will likely be removed in a future release.
ERROR: Something went wrong when installing logstash-input-http, message: certificate verify failed
```
解决方式
修改lib/pluginmanager/install.rb文件
在require "fileutils"这行
添加OpenSSL::SSL.const_set(:VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE)

### 报错二、
MAY NOT BE VERIFIED
```csharp
[root@x logstash-8.2.0]# ./bin/logstash-plugin install logstash-input-http
Using bundled JDK: /opt/logcat/logstash-8.2.0/jdk
OpenJDK 64-Bit Server VM warning: Option UseConcMarkSweepGC was deprecated in version 9.0 and will likely be removed in a future release.
/opt/logcat/logstash-8.2.0/lib/pluginmanager/install.rb:25: warning: already initialized constant VERIFY_PEER
Validating logstash-input-http
Resolving mixin dependencies

Updating mixin dependencies logstash-mixin-ecs_compatibility_support
                             !!!SECURITY WARNING!!!

The SSL HTTP connection to:

  index.rubygems.org:443

                           !!!MAY NOT BE VERIFIED!!!

On your platform your OpenSSL implementation is broken.

There is no difference between the values of VERIFY_NONE and VERIFY_PEER.

This means that attempting to verify the security of SSL connections may not
work.  This exposes you to man-in-the-middle exploits, snooping on the
contents of your connection and other dangers to the security of your data.
```
修改下载源，logstash-8.2.0/Gemfile
修改source "https://mirrors.tuna.tsinghua.edu.cn/rubygems/"
