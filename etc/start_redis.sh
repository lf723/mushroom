#增加执行权限
redisInstaceNum=10
prefix=`pwd`/etc/redis/
chmod +x ${prefix}redis-server

#停止redis-server
pkill redis-server

#定义初始端口
initport=16379

for((i=1;i<=${redisInstaceNum};i++))
do
	#修改redis/redis.conf中的port,启动实例,由16379开始,默认配置为6379端口
	sed -i "s/port 6379/port ${initport}/g" ${prefix}redis.conf
	#修改log文件名称
	sed -i "s#logfile redis-log#logfile ${prefix}redis-log-${i}#g" ${prefix}redis.conf
	#修改pid名称
	sed -i "s#pidfile redis_6379.pid#pidfile ${prefix}redis_${initport}.pid#g" ${prefix}redis.conf

	#启动redis实例
	${prefix}redis-server ${prefix}redis.conf

	#启动完还原
	sed -i "s/port ${initport}/port 6379/g" ${prefix}redis.conf
	sed -i "s#logfile ${prefix}redis-log-${i}#logfile redis-log#g" ${prefix}redis.conf
	sed -i "s#pidfile ${prefix}redis_${initport}.pid#pidfile redis_6379.pid#g" ${prefix}redis.conf

	echo "runing redis-server-${i} ok...\n"

	let initport=${initport}+1
done