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
### 1.&nbsp;在macOS High Sierra 10.13.4上安装docker
#### 1)&nbsp;安装Python 3.6.4：
