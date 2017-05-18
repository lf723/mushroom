# @Author: linfeng
# @Date:   2017-02-07 14:03:13
# @Last Modified by:   linfeng
# @Last Modified time: 2017-02-09 14:43:11

#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export WORLD_WORK_THREAD=8
#是否启动为守护模式
export WORLD_DAEMON=0

#游服配置
export WORLD_HOST="0.0.0.0"
export WORLD_PORT=11000
export WORLD_MAX_CLIENT=10000

#cluster配置
export WORLD_MONITOR_NODE="monitor"
export WORLD_CLUSTER_IP="127.0.0.1"
export WORLD_CLUSTER_PORT="7001"

#WEB监听端口
export WORLD_WEB_PORT=80

#skynet DEBUG端口(telnet),0为不开启
export WORLD_DEBUG_PORT=0

#时区
export WORLD_TIMEZONE=8

#服务器ID
export WORLD_SERVER_ID=0

#远程调试开关
export WORLD_REMOTE_DEBUG=0
export WORLD_REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/world.conf