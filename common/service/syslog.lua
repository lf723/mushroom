-- @Author: linfeng
-- @Date:   2017-01-09 15:32:12
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-07 17:01:12

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local string = string
local table = table
local math = math

local logger = require "log.core"
local thread_co --日志写入协程
local log_info = {} --待写入文件的日志信息

--日志落地文件协程
local function LogWorker( ... )
	local sleep_interval = 1
	while true do
		if log_info[1] ~= nil then
			for _,log in pairs(log_info) do
				logger.write(log.level, log.name, log.msg, log.dir, log.basename)
			end
			log_info = {}
			sleep_interval = 1
		else
			sleep_interval = sleep_interval + 1
		end

		skynet.sleep(sleep_interval)
	end
end

function accept.log( msg )
	table.insert(log_info,msg)
	skynet.wakeup(thread_co) --唤醒协程
end

function init( selfNodeName )
	logger.init(0,0,0,selfNodeName)

	thread_co = assert(skynet.fork(LogWorker),"syslog fork LogWorker fail")
end

function exit( ... )
	skynet.wakeup(thread_co)
	logger.exit()
end