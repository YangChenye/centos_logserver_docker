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

> 本段一部分参考[CentOS上配置rsyslog客户端用以远程记录日志](https://www.linuxidc.com/Linux/2015-02/112989.htm)

rsyslog是一个开源工具，被广泛用于Linux系统以通过TCP/UDP协议转发或接收日志消息。rsyslog守护进程可以被配置成两种环境，一种是配置成日志收集服务器，rsyslog进程可以从网络中收集其它主机上的日志数据，这些主机会将日志配置为发送到另外的远程服务器。rsyslog的另外一个用法，就是可以配置为客户端，用来过滤和发送内部日志消息到本地文件夹（如/var/log）或一台可以路由到的远程rsyslog服务器上。

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

> 本段一部分参考[CentOS上配置rsyslog客户端用以远程记录日志](https://www.linuxidc.com/Linux/2015-02/112989.htm)和[centos7的syslog知识点](https://blog.csdn.net/u011630575/article/details/51966725)

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

> 本段参考[centos7 部署Apache服务器](https://blog.csdn.net/u011277123/article/details/77847360)和[CentOS Linux系统下更改Apache默认网站目录](https://blog.csdn.net/u014702999/article/details/55667090/)

Apache程序是目前拥有很高市场占有率的Web服务程序之一，其跨平台和安全性广泛被认可且拥有快速、可靠、简单的API扩展。 它的名字取自美国印第安人土著语，寓意着拥有高超的作战策略和无穷的耐性，在红帽RHEL5、6、7系统中一直作为着默认的Web服务程序而使用，并且也一直是红帽RHCSA和红帽RHCE的考试重点内容。Apache服务程序可以运行在Linux系统、Unix系统甚至是Windows系统中，支持基于IP、域名及端口号的虚拟主机功能、支持多种HTTP认证方式、集成有代理服务器模块、安全Socket层(SSL)、能够实时监视服务状态与定制日志消息，并有着各类丰富的模块支持。

#### 1)&nbsp;安装Apache服务

安装Apache服务程序(apache服务的软件包名称叫做httpd)：`yum install httpd -y`。

将Apache服务添加到开机自启中：
```
systemctl start httpd
systemctl enable httpd
```

打开浏览器，访问网站`http://127.0.0.1`，查看是否出现默认引导页，若出现该网页，则启动成功。***需要注意的是，由于我们使用的是docker容器技术，如果直接访问`http://127.0.0.1`，访问的是本物理机的该地址，而不是container的。还记得之前我们在启动容器时进行了`-p 8000:80`的端口映射吗，由于Apache服务器默认监听的是80端口，所以我们才进行了这样的映射，那么在测试时，访问的网站就应该是`http://127.0.0.1:8000`了，也就是说，把物理机的8000端口映射到了container的80端口之后，对container80端口的访问实际应该通过8000端口进行。***

#### 2)&nbsp;更改默认网站数据保存路径

对于Linux系统中服务的配置就是在修改其配置文件，因此还需要知道这些配置文件分别干什么用的，以及存放到了什么位置：

|配置文件|路径|
|------|------|
|服务目录|/etc/httpd|
|主配置文件|/etc/httpd/conf/httpd.conf|
|网站数据目录|/var/www/html|
|访问日志|/var/log/httpd/access_log|
|错误日志|/var/log/httpd/error_log|

我们来看主配置文件：`vi /etc/httpd/conf/httpd.conf`

其中最常用的参数为：

|参数|功能|
|------|------|
|DocumentRoot|网站数据目录|
|Listen|监听的IP地址与端口号|
|DirectoryIndex|默认的索引页页面|

从上面表格中可以得知DocumentRoot正是用于定义网站数据保存路径的参数，其参数的默认值是把网站数据存放到了`/var/www/html`目录中的，而网站首页的名称应该叫做index.html，因此可以手动的向这个目录中写入一个文件来替换掉httpd服务程序的默认网页，这种操作是立即生效的：
`echo "hello everyone" > /var/www/html/index.html`

访问`http://127.0.0.1:8000`可以看到主页已经被更改了，测试成功。

现在我们来修改网站的数据目录：

首先备份主配置文件`cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak`，新建一个文件夹`mkdir /var/logserver_website`，然后修改主配置文件中的DocumentRoot参数`vi /etc/httpd/conf/httpd.conf`，将它修改为我们刚才新建的文件夹。***需要注意的是，在修改主配置文件的时候，不能只修改DocumentRoot这一个参数，之后的所有出现`/var/www/html/`这个路径的地方都要修改为我们自己的路径，否则会出现无权访问的错误。修改如下：***
```
#
# DocumentRoot: The directory out of which you will serve your
# documents. By default, all requests are taken from this directory, but
# symbolic links and aliases may be used to point to other locations.
#
DocumentRoot "/var/logserver_website"

#
# Relax access to content within /var/www.
#
<Directory "/var/logserver_website">
    AllowOverride None
    # Allow open access:
    Require all granted
</Directory>

# Further relax access to the default document root:
<Directory "/var/logserver_website">
    #
    # Possible values for the Options directive are "None", "All",
    # or any combination of:
    #   Indexes Includes FollowSymLinks SymLinksifOwnerMatch ExecCGI MultiViews
    #
    # Note that "MultiViews" must be named *explicitly* --- "Options All"
    # doesn't give it to you.
    #
    # The Options directive is both complicated and important.  Please see
    # http://httpd.apache.org/docs/2.4/mod/core.html#options
    # for more information.
    #
    Options Indexes FollowSymLinks
    
    #
    # AllowOverride controls what directives may be placed in .htaccess files.
    # It can be "All", "None", or any combination of the keywords:
    #   Options FileInfo AuthConfig Limit
    #
    AllowOverride None

    #
    # Controls who can get stuff from this server.
    #
    Require all granted
</Directory>
```

保存配置文件，并重启Apache服务：`systemctl restart httpd`。

#### 3)&nbsp;禁用默认引导页
当然我们会发现，在经过这样一番操作之后，再次访问`http://127.0.0.1:8000`出现的仍旧是默认引导页面，并不是我们修改之后的文件夹，不论我们修改过的文件夹中是否放有文件（包括index.html文件）。（通过`echo "hello world" > /var/logserver_website/test.json`新建测试文件）

仔细观察默认引导页，发现它可以被禁用：
> To prevent this page from ever being used, follow the instructions in the file: `/etc/httpd/conf.d/welcome.conf`

于是打开这个文件`vi /etc/httpd/conf.d/welcome.conf`，按照它的要求把所有的内容全部注释掉。

这样再次访问网页，发现不会再出现默认引导页了，但是仍然看不到文件夹中的文件，屏幕上显示文件夹中一片空白，不论我们是否通过命令新建了文件，都是空白。

#### 4)&nbsp;对新网站数据保存路径提权
这个显示不出来文件的问题，查找资料发现是因为权限不够。因为你的`/var/logserver_website`的权限是750，apache这个用户没有权限访问，需要更改权限：

`chmod -R 755 /var/logserver_website`

-R表示递归操作，即对当前文件夹下的所有内容进行同样的提权。

然后去访问`http://127.0.0.1:8000`，发现正常运行了，可以显示其中的文件和目录。

### 5.&nbsp;按天切割log文件，将切割好的log文件放入Apache服务器的文件目录中

> 本段参考[CentOS 7下使用Logrotate管理日志](https://www.jianshu.com/p/6d3647f02437)和[利用Centos6系统自带的logrotate切割nginx日志](https://blog.csdn.net/magerguo/article/details/49638469)

Logrotate是一个日志文件管理工具。用来把旧文件轮转、压缩、删除，并且创建新的日志文件。我们可以根据日志文件的大小、天数等来转储，便于对日志文件管理，一般都是通过cron计划任务来完成的。

#### 1)&nbsp;安装

通过这个命令安装logrotate和cron：`yum install logrotate cron`。

默认状态文件在`/var/lib/logrotate.status`

默认配置文件是`/etc/logrotate.conf`

#### 2)&nbsp;运行原理

Logrotate是基于CRON来运行的，其脚本在`/etc/cron.daily/logrotate`
```
#!/bin/sh

/usr/sbin/logrotate /etc/logrotate.conf
EXITVALUE=$?
if [ $EXITVALUE != 0 ]; then
    /usr/bin/logger -t logrotate "ALERT exited abnormally with [$EXITVALUE]"
fi
exit 0
```

实际运行时，Logrotate会调用配置文件`/etc/logrotate.conf`
```
# see "man logrotate" for details
# rotate log files weekly
weekly

# keep 4 weeks worth of backlogs
rotate 4

# create new (empty) log files after rotating old ones
create

# use date as a suffix of the rotated file
dateext

# uncomment this if you want your log files compressed
#compress

# RPM packages drop log rotation information into this directory
include /etc/logrotate.d

# no packages own wtmp and btmp -- we'll rotate them here
/var/log/wtmp {
    monthly
    create 0664 root utmp
        minsize 1M
    rotate 1
}

/var/log/btmp {
    missingok
    monthly
    create 0600 root utmp
    rotate 1
}

# system-specific logs may be also be configured here.
```

这里的设置是全局的，而在`/etc/logrotate.d`目录里，可以定义每项应用服务的配置文件，并且定义会覆盖之前全局的定义。

#### 3)&nbsp;配置参数

|参数|功能|
|------|------|
|compress|使用gzip来压缩日志文件|
|nocompress|日志不压缩的参数|
|compresscmd|指定压缩工具，默认gzip|
|uncompresscmd |指定解压工具，默认gunzip|
|delaycompress |推迟要压缩的文件，直到下一轮询周期再执行压缩，可与compress搭配使用|
|dateext |切割的文件名字带有日期信息|
|dateformat |格式化归档日期后缀，只有%Y, %m,  %d 和%s|
|daily |日志按天切割|
|weekly |日志按周切割|
|monthly |日志按月切割|
|yearly |日志按年切割|
|maxage count |删除count天前的切割日志文件|
|rotate count |删除count个外的切割日志文件|
|notifempty |文件为空时，不进行切割|
|size size |日志文件根据大小规定进行切割，默认单位是byte，也可指定kb, M, G；So size 100, size 100k, size 100M and size 100G are all valid.|
|minsize size |文件大小超过size后才能进行切割，此时会略过时间参数|
|postrotate/endscript |在所有其它指令完成后，postrotate和endscript里面指定的命令将被执行|
|sharedscripts |在所有的日志文件都切割完毕后统一执行一次脚本。当声明日志文件的时候使用通配符时需要用到|
|olddir |指定切割后的日志文件存放在directory，必须和当前日志文件在同一个文件系统|
|create mode owner group |新日志文件的权限，属主属组|

#### 4)&nbsp;针对某一个具体文件进行配置

在上一小节中，我们已经说了，可以在`/etc/logrotate.d`目录里定义每项应用服务的配置文件。现在我们就要针对`/var/log/messages`这个系统自身的log文件进行切割的配置文件的定义，为了实现对它的切割。

创建messages的配置文件：`vi /etc/logrotate.d/messages `

在其中输入
```
/var/log/messages {
 missingok
 copytruncate
 notifempty
 daily
 rotate 30
 olddir /var/logserver_website
 dateext
 postrotate
  /bin/kill/ -HUP `cat /var/run/syslogd.pid 2>dev/null` 2 >/dev/null || true
 endscript
}
```
其中：

`missingok`代表如果日志丢失，不报错继续切割下一个日志

`copytruncate`用于还在打开中的日志文件，把当前日志备份并截断

`notifempty`表示文件为空时，不进行切割

`daily`表示按天切割

`rotate 30`表示存储30天的日志文件

`olddir /var/logserver_website`指定切割后的日志文件存放在/var/logserver_website

`dateext`表示切割的文件名字带有日期信息

`postrotate/endscript`表示切割之后执行命令，***如果没有这个语句的话，由于切割之后会删除原来的日志文件，会造成新的日志无法被记录下来。这个命令的意思是重启日志服务，也就会新建一个messages文件，这样切割之后新产生的日志文件就可以被继续记录***

到这里，我们的配置文件就写好了，接下来需要进行一下测试：

使用命令：`logrotate -d /etc/logrotate.d/messages`，可以查看当前文件是否需要切割，以及切割时的一些信息。

在将它添加到定时任务之前，可以使用命令：`logrotate -f /etc/logrotate.d/messages`手动强制切割一次，测试是否可以正常切割。

***需要注意的是，切割之后保存的文件名为messages-20180807，这个文件包含了切割时刻之前的messages文件内容，也就是会把现有messages里面所有东西切割成一个文件，命名为切割时刻的日期。如果上一次切割是在20180805，那么这个20180807的文件会包含0805-0807的所有内容。而且，如果已经有20180807这个文件存在，当天（20180807）再对messages进行切割，并不能切割成功，不会动messages里的内容，也不会动原20180807里的内容，仍旧像切割之前一样存储。这也就意味着，我们必须完全精确的在每天23:59:59进行切割，否则就会出现对log信息的划分错误，很不利于日后的查看***

关于精准分割，我没有去尝试，不过可以参考[rsyslog、logrotate切割保存日志日期不准确的问题](https://blog.csdn.net/a_tu_/article/details/73558006)。对于定时的分割我想也可以参考这一篇文章。

### 6.&nbsp;按主机名和日期转存log信息，利用syslog协议
> 本段参考[教你一步一步利用rsyslog搭建自己的日志系统](https://cnodejs.org/topic/598a6da62d4b0af4750353ae)和[Centos6.5部署Rsyslog-日志的存储方式及监测服务状态](https://www.cnblogs.com/daynote/p/8996160.html)

#### 1)&nbsp;syslog协议
![syslog](https://raw.githubusercontent.com/YangChenye/centos_logserver_docker/master/pictures/syslog-stant.png)

syslog的协议中包含了时间和主机名，因此可以直接进行分类，不需要logrotate。

#### 2)&nbsp;按主机名和日期转存log信息
前面在构建转发log信息的user时，我们在其配置文件中加入了一些语句，使它将自己的所有log信息通过IP地址转发给一台远程的服务器。同样的，我们可以在logserver的配置文件中加入一些语句，命令logserver将自己的所有log信息按照一定的规则转存。结合之前的Apache服务器的构建，可以想到的是，如果可以让logserver将这些log信息转存到logserver自身的Apache服务器的网站资源目录下，我们就可以很方便的访问了。

在`/etc/rsyslog.conf`中加入如下配置：

```
$template myFormat,"/var/logserver_website/%fromhost-ip%/%$year%%$month%%$day%.log"
*.* ?myFormat
& ~
```

这些语句的含义分别是：1.自定义一个按照主机ip地址存储的路径，存储时的文件名是日期；2.将所有的log信息按照ip地址和日期归类，存储到之前定义的路径和文件中；3.这个语句的含义我不太清楚，但是没有它就无法正确执行。

这样就配置好了，我们可以检查这个路径，可以看到里面分类存储了log文件，这些log文件的划分很准确，因为这是与syslog协议相关的。

需要注意的是，如果我们这时访问`http://127.0.0.1:8000`，里面并不会出现这些文件。这是因为这些新加进去的文件的权限问题，此时只需要再次执行`chmod -R 755 /var/logserver_website`进行权限的提升，就可以访问新加进去的文件了。

## 四.&nbsp;后续的工作
现在已有的是从某一个端口向外发送信息的待测试服务器，量很大。我们只能去监听它，不能说在待测设备上面安装一个服务。那么“在待测机上配置socat，让它们把自己的端口转发给logserver，logserver负责接收并转存（三.2.的方法）”行不通。并且由于发送出来的信息不符合syslog协议，因此基于syslog的转存（三.6.的方法）行不通。

尝试用socat监听10.0.21.101:5000：```socat - TCP:10.0.21.101:5000 | echo "`date`" >> /var/log/messages```

试着将屏幕上打印的监听到的内容写入messages文件，然后再尝试使用logrotate分割。



