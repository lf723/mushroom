-- @Author: linfeng
-- @Date:   2017-01-09 15:55:55
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-07 17:04:22

--Log Define, level = (0-199)
--系统级日志
E_LOG_DEBUG 				= 			{ name = "Debug", 			level = 0 }
E_LOG_WARNING 				= 			{ name = "Warning", 		level = 1 }
E_LOG_INFO					=			{ name = "Info", 			level = 2 }
E_LOG_ERROR					=			{ name = "Error", 			level = 3 }
E_LOG_FATAL					=			{ name = "Fatal", 			level = 4 }

--skynet的log信息
E_LOG_SKYNET				=			{ name = "Skynet", 			level = 5 }


--系统相关日志写入
function LOG_SYS( loginfo, fmt, ... )
	local msg = string.format(fmt, ...)
	local info = debug.getinfo(2)
	if info then
		msg = string.format("%s [%s:%d] %s", os.date("%Y-%m-%d %H:%M:%S"), info.short_src, info.currentline, msg)
	end

	loginfo.msg = msg
	loginfo.dir = LOG_PATH
	loginfo.basename = true
	SM.syslog.post.log(loginfo) --loginfo = { name = "", level = x, msg = "", dir = "", basename = true}
end

--用户数据相关日志写入(运营向)
function LOG_USER( loginfo, fmt, ... )
	local msg = string.format(fmt, ...)
	loginfo.msg = msg
	loginfo.dir = EVENT_LOG_PATH
	loginfo.basename = false
	SM.syslog.post.log(loginfo) --loginfo = { name = "", level = x, msg = "", dir = "", basename = false}
end


----------------------部分LOG实例-----------------------
function LOG_DEBUG( fmt, ... )
	LOG_SYS(E_LOG_DEBUG,fmt, ...)
end

function LOG_WARNING( fmt, ... )
	LOG_SYS(E_LOG_WARNING,fmt, ...)
end

function LOG_INFO( fmt, ... )
	LOG_SYS(E_LOG_INFO,fmt, ...)
end

function LOG_ERROR( fmt, ... )
	LOG_SYS(E_LOG_ERROR,fmt, ...)
end

function LOG_FATAL( fmt, ... )
	LOG_SYS(E_LOG_FATAL,fmt, ...)
end
