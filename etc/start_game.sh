# @Author: linfeng
# @Date:   2017-02-07 14:03:13
# @Last Modified by:   linfeng
# @Last Modified time: 2017-08-14 11:13:46

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
export CONNECT_IP="192.168.222.128"

#cluster配置
export MONITOR_NODE_NAME="monitor"
export CLUSTER_IP="127.0.0.1"
export CLUSTER_PORT="7005"
export CLUSTER_NODE="game"

#WEB监听端口
export WEB_PORT=8005

#skynet DEBUG端口(telnet),0为不开启
export DEBUG_PORT=6005

#服务器ID
export SERVER_ID=1

#启动游服
chmod +x main
mkdir -p logs
./main etc/game.conf