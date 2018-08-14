# centos_logserver_docker
Steps and detail problems to build a logserver using CentOS image in docker.
## 一.&nbsp;在macOS上开启Apache服务器
Mac自带了Apache环境，我们要做的只是稍微配置一下
### 1.&nbsp;启动Apache
在终端输入：`sudo apachectl start`，这样就将Mac自带的Apache启动了。

在浏览器输入`http://localhost`或`http://127.0.0.1`，会显示“It works!”，说明服务器已经启动成功了。

Apache默认的根目录在`/Library/WebServer/Documents/`下。
### 2.&nbsp;配置服务器
在/Users/apple(当前用户名)目录下创建一个名为"Sites"的文件夹：
`mkdir /Users/apple(当前用户名)/Sites`

切换工作目录下：
`cd /etc/apache2`

使用命令`sudo cp httpd.conf httpd.conf.bak`备份文件。如果操作出现错误，可以使用命令`sudo cp httpd.conf.bak httpd.conf`恢复备份的 httpd.conf 文件。

用 vim 编辑 Apache 的配置文件 httpd.conf：`sudo vim httpd.conf`

找到`DocumentRoot`附近，修改为：
```
DocumentRoot "/Users/apple(当前用户名)/Sites"
<Directory "/Users/apple(当前用户名)/Sites">
```

之后找到`Options FollowSymLinks`，修改为`Options Indexes FollowSymLinks`。

接下来查找php`:/php`，将
`LoadModule php7_module libexec/apache2/libphp7.so`这句话前面的注释去掉。

保存并退出`:wq`。

切换工作目录：`cd /etc`，拷贝 php.ini 文件：`sudo cp php.ini.default php.ini`。

### 3.&nbsp;重新启动apache服务器

在终端输入：`sudo apachectl -k restart`

这个时候如果在浏览器地址输入`http://127.0.0.1/`，就会将“Sites”文件夹中的目录列出来了。同一工作组里的电脑可以通过本电脑的ip地址来访问本电脑上的文件。


## 二.&nbsp;使用CentOS镜像创建User节点
### 1.&nbsp;创建Container
使用命令`docker run -i -t -d --privileged centos /usr/sbin/init`，可以启动一个一直停留在后台运行的CentOS。如果少了/bin/bash的话，Docker会生成一个Container但是马上就停止了，不会一直运行，即使有了-d参数。

使用命令`docker exec -it <容器名或者ID> /bin/bash`，可以进入这个CentOS的容器。

### 2.&nbsp;向指定IP地址发送log
本段一部分参考[CentOS上配置rsyslog客户端用以远程记录日志](https://www.linuxidc.com/Linux/2015-02/112989.htm)
> rsyslog是一个开源工具，被广泛用于Linux系统以通过TCP/UDP协议转发或接收日志消息。rsyslog守护进程可以被配置成两种环境，一种是配置成日志收集服务器，rsyslog进程可以从网络中收集其它主机上的日志数据，这些主机会将日志配置为发送到另外的远程服务器。rsyslog的另外一个用法，就是可以配置为客户端，用来过滤和发送内部日志消息到本地文件夹（如/var/log）或一台可以路由到的远程rsyslog服务器上。

#### 1)&nbsp;安装Rsyslog守护进程
在CentOS 6和7上，rsyslog守护进程已经预先安装了。要验证rsyslog是否已经安装到你的CentOS系统上，请执行如下命令：
```
rpm -qa | grep rsyslog
rsyslogd -v
```
如果处于某种原因，rsyslog守护进程没有出现在你的系统中，请使用以下命令来安装：`yum install rsyslog`。

#### 2)&nbsp;配置Rsyslog客户端
接下来的步骤，是要将你的CentOS容器转变成rsyslog客户端，将其所有内部日志消息发送到远程中央日志服务器上。

使用文本编辑器打开位于/etc路径下的rsyslog主配置文件：
`vi /etc/rsyslog.conf`

添加以下声明到文件底部。将IP地址替换为你的远程rsyslog服务器的IP地址：
`*.* @192.168.1.25:514`

上面的声明告诉rsyslog守护进程，将系统上各个设备的各种日志消息路由到远程rsyslog服务器（192.168.1.25）的UDP端口514。

修改配置文件后，你需要重启进程以激活修改（CentOS 7）：
`systemctl restart rsyslog.service`

### 3.&nbsp;保存，并再次使用配置好的Container
#### 1)&nbsp;保存
使用`ctrl P + ctrl Q`离开当前进入的CentOS的Container。

通过`docker commit <容器ID> <镜像名:版本号>`来保存当前对Container的更改。

#### 2)&nbsp;再次调用
在上一步中，我将配置好的客户端CentOS保存为了“centos_user“，之后将使用这个名称，读者可以自行替换。

调用时，使用命令：
`docker run -i -t -d --privileged --name user centos_user /usr/sbin/init`

这是由于，如果像这样写`docker run -i -t -d --name user centos_user /bin/bash`，在调用systemctl命令时，会报错`docker Failed to get D-Bus connection`，这个的原因是因为dbus-daemon没能启动。其实systemctl并不是不可以使用。将你的CMD或者entrypoint设置为/usr/sbin/init即可。会自动将dbus等服务启动起来。在创建docker容器时也需要添加“--privileged”。「本报错参考[配置centos7解决 docker Failed to get D-Bus connection 报错](https://blog.csdn.net/xiaochonghao/article/details/64438246)」

使用如下命令进入container、修改要将log发送到的ip地址（如果ip地址动态分配，那么每次重新接入网络都需要修改）、重启rsyslog服务：
```
docker exec -it user /bin/bash
vi /etc/rsyslog.conf
systemctl restart rsyslog.service
```


## 三.&nbsp;使用CentOS镜像创建Logserver节点
### 1.&nbsp;创建container
使用命令`docker run -i -t -d -p 8000:80 -p 2222:22 -p 10000:514 --privileged centos /usr/sbin/init`，可以启动一个一直停留在后台运行的CentOS。如果少了/bin/bash的话，Docker会生成一个Container但是马上就停止了，不会一直运行，即使有了-d参数。

使用命令`docker exec -it <容器名或者ID> /bin/bash`，可以进入这个CentOS的容器。


### 2.&nbsp;接收user发送的log
本段一部分参考[CentOS上配置rsyslog客户端用以远程记录日志](https://www.linuxidc.com/Linux/2015-02/112989.htm)和[centos7的syslog知识点](https://blog.csdn.net/u011630575/article/details/51966725)
#### 1)&nbsp;安装Rsyslog守护进程
在CentOS 6和7上，rsyslog守护进程已经预先安装了。要验证rsyslog是否已经安装到你的CentOS系统上，请执行如下命令：
```
rpm -qa | grep rsyslog
rsyslogd -v
```
如果处于某种原因，rsyslog守护进程没有出现在你的系统中，请使用以下命令来安装：`yum install rsyslog`。

#### 2)&nbsp;配置Rsyslog服务器
将所有客户端的系统日志送给远程日志服务器，远程服务器用来接收和集中所有客户端送来的系统日志。

采用UDP协议发送和接收，在远程服务器端配置文件`/etc/rsyslog.conf`开启下面两行
```
# Provides UDP syslog reception
$ModLoad imudp
$UDPServerRun 514
```

修改配置文件后，你需要重启进程以激活修改（CentOS 7）：
`systemctl restart rsyslog.service`

测试时，可以重启某台客户端的rsyslog服务看看远程的服务器能不能收到日志，如果没有收到日志是不是防火墙挡住了，如果没有使用标准的端口还要看看是不是SELinux服务开启了。

当然要想正确地发送，客户端的配置文件中的IP地址必须是远程rsyslog服务器的IP地址。***在这里需要注意的是，docker的container需要和物理机进行端口的映射，不然无法与外界通信，我们之前在启动容器的时候定义了三个端口映射，其中将物理机的10000号端口映射到了docker容器的514号端口。那么，此时，客户端container中配置文件`*.* @<logserver ip address>:514`应该改为`*.* @<logserver ip address>:10000`，因为实际通信使用的端口是10000。当然读者也可以选择自己喜欢的端口进行映射。***

可以在服务器上使用命令`tailf /var/log/messages`实时监控是否收到了客户端发来的log信息。

### 3.&nbsp;修改log的时间显示格式
#### 1)&nbsp;设置时区
由于时区设置的原因，日志的时间戳会比本机时间晚8小时（北京时间），为了方便我们查看日志和之后实现日志的按天分割，需要将时区设置为北京时间。

> 本节参考[CentOS 7 时区设置](https://blog.csdn.net/achang21/article/details/52606027)和[CentOS7修改时区的正确姿势](https://blog.csdn.net/yin138/article/details/52765089)

在 CentOS 7 中, 引入了一个叫 timedatectl 的设置程序，用法很简单:
```
timedatectl  # 查看系统时间方面的各种状态
timedatectl list-timezones # 列出所有时区
timedatectl set-local-rtc 1 # 将硬件时钟调整为与本地时钟一致, 0 为设置为 UTC 时间
timedatectl set-timezone Asia/Shanghai # 设置系统时区为上海
```

或者：

正确的修改CentOS7 时区的方式：`ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime`；其他系统的修改文件可能是`/var/etc/localtime`。错误的方式：通过`cp`命令覆盖`/etc/localtime`时间。

#### 2)&nbsp;修改时间戳显示格式

> 本节参考[CentOS 7 修改日志时间戳格式](http://www.mamicode.com/info-detail-2373089.html)

默认的时间戳格式是

`Jul 14 13:30:01 localhost systemd: Starting Session 38 of user root.`

看着不是很方便，现修改为以下格式

`2018-07-14 13:32:57 desktop0 systemd: Starting System Logging Service...`

修改`/etc/rsyslog.conf`为：
```
# Use default timestamp format
#$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat # 这行是原来的将它注释，添加下面两行
$template CustomFormat,"%$NOW% %TIMESTAMP:8:15% %HOSTNAME% %syslogtag% %msg%\n"
$ActionFileDefaultTemplate CustomFormat
```
然后重启 rsyslog 服务：`systemctl restart rsyslog.service`

### 4.&nbsp;启动并配置Apache服务器，使其他电脑能查看本机文件
#### 1)&nbsp;

### 5.&nbsp;按天切割log文件，将切割好的log文件放入Apache服务器的文件目录中
#### 1)&nbsp;



