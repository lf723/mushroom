#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export WORK_THREAD=8
#是否启动为守护模式
export DAEMON=0

#cluster配置
export CLUSTER_NODE="monitor"
export CLUSTER_IP="127.0.0.1"
export CLUSTER_PORT="7000"

#WEB监听端口
export WEB_PORT=8000

#skynet DEBUG端口(telnet),0为不开启
export DEBUG_PORT=6666

#时区
export TIMEZONE=8

#服务器ID
export SERVER_ID=0

#远程调试开关
export REMOTE_DEBUG=0
export REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/monitor.conf
