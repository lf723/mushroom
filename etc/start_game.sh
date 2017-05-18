# @Author: linfeng
# @Date:   2017-02-07 14:03:13
# @Last Modified by:   linfeng
# @Last Modified time: 2017-02-09 14:58:49

#开启core,修改最大文件描述符
ulimit -c unlimited
ulimit -n 65535

#工作线程数量(根据CPU核心数而定)
export GAME_WORK_THREAD=8
#是否启动为守护模式
export GAME_DAEMON=0

#cluster配置
export GAME_MONITOR_NODE="monitor"
export GAME_CLUSTER_IP="127.0.0.1"
export GAME_CLUSTER_PORT="7004"

#WEB监听端口
export GAME_WEB_PORT=80

#skynet DEBUG端口(telnet),0为不开启
export GAME_DEBUG_PORT=0

#时区
export GAME_TIMEZONE=8

#服务器ID
export GAME_SERVER_ID=0

#远程调试开关
export GAME_REMOTE_DEBUG=0
export GAME_REMOTE_DEBUG_IP="127.0.0.1"

#启动游服
chmod +x main
./main etc/game.conf