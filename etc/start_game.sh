# @Author: linfeng
# @Date:   2017-02-07 14:03:13
# @Last Modified by:   linfeng
# @Last Modified time: 2017-06-19 11:13:19

#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export WORK_THREAD=8
#是否启动为守护模式
export DAEMON=0

#游服配置
export HOST="0.0.0.0"
export PORT=11000
export MAX_CLIENT=10000
export CONNECT_IP="127.0.0.1"

#cluster配置
export MONITOR_NODE_NAME="monitor"
export CLUSTER_IP="127.0.0.1"
export CLUSTER_PORT="7005"
export CLUSTER_NODE="game"

#WEB监听端口
export WEB_PORT=8005

#skynet DEBUG端口(telnet),0为不开启
export DEBUG_PORT=0

#时区
export TIMEZONE=8

#服务器ID
export SERVER_ID=0

#远程调试开关
export REMOTE_DEBUG=0
export REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/game.conf