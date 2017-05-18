#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export LOGIN_WORK_THREAD=8
#是否启动为守护模式
export LOGIN_DAEMON=0

#cluster配置
export LOGIN_CLUSTER_NODE="login"
export LOGIN_CLUSTER_IP="127.0.0.1"
export LOGIN_CLUSTER_PORT="7002"

#登陆服务器端口
export LOGIN_PORT=10000

#WEB监听端口
export LOGIN_WEB_PORT=82

#skynet DEBUG端口(telnet),0为不开启
export LOGIN_DEBUG_PORT=0

#时区
export LOGIN_TIMEZONE=8

#服务器ID
export LOGIN_SERVER_ID=0

#远程调试开关
export LOGIN_REMOTE_DEBUG=0
export LOGIN_REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/login.conf