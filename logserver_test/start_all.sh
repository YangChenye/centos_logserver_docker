docker run -i -t -d --privileged --name user1 centos_user /usr/sbin/init
docker run -i -t -d --privileged --name user2 centos_user /usr/sbin/init
docker run -i -t -d -p 10000:514/udp -p 2222:22 -p 8000:80 --privileged --name logserver centos_logserver /usr/sbin/init
