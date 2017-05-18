#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export CENTER_WORK_THREAD=8
#是否启动为守护模式
export CENTER_DAEMON=0

#cluster配置
export CENTER_CLUSTER_NODE="center"
export CENTER_CLUSTER_IP="127.0.0.1"
export CENTER_CLUSTER_PORT="7003"

#WEB监听端口
export CENTER_WEB_PORT=83

#skynet DEBUG端口(telnet),0为不开启
export CENTER_DEBUG_PORT=0

#时区
export CENTER_TIMEZONE=8

#服务器ID
export CENTER_SERVER_ID=0

#远程调试开关
export CENTER_REMOTE_DEBUG=0
export CENTER_REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/center.conf