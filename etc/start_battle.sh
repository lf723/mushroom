# @Author: linfeng
# @Date:   2017-06-19 09:45:31
# @Last Modified by:   linfeng
# @Last Modified time: 2017-08-14 11:13:23

#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export WORK_THREAD=8
#是否启动为守护模式
export DAEMON=1

#cluster配置
export MONITOR_NODE_NAME="monitor"
export CLUSTER_IP="127.0.0.1"
export CLUSTER_PORT="7006"
export CLUSTER_NODE="battle"

#WEB监听端口
export WEB_PORT=8006

#skynet DEBUG端口(telnet),0为不开启
export DEBUG_PORT=6006

#服务器ID
export SERVER_ID=1

#启动游服
chmod +x main
mkdir -p logs
./main etc/battle.conf