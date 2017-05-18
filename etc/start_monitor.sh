#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export MONITOR_WORK_THREAD=8
#是否启动为守护模式
export MONITOR_DAEMON=0

#cluster配置
export MONITOR_CLUSTER_NODE="monitor"
export MONITOR_CLUSTER_IP="127.0.0.1"
export MONITOR_CLUSTER_PORT="7000"

#WEB监听端口
export MONITOR_WEB_PORT=81

#skynet DEBUG端口(telnet),0为不开启
export MONITOR_DEBUG_PORT=0

#时区
export MONITOR_TIMEZONE=8

#服务器ID
export MONITOR_SERVER_ID=0

#远程调试开关
export MONITOR_REMOTE_DEBUG=0
export MONITOR_REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/monitor.conf