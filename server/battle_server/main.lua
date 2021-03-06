-- @Author: linfeng
-- @Date:   2017-02-09 14:43:27
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 18:13:12

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local function initLogicLuaService( selfNodeName )
	
end

skynet.start(function ( ... )
	
	local selfNodeName = skynet.getenv("clusternode")..skynet.getenv("serverid")
	--init log
	snax.uniqueservice("syslog", selfNodeName)

	--init web
	local webPort = tonumber(skynet.getenv("webport")) or 0
	if webPort > 0 then
		skynet.uniqueservice("web", webPort)
	end

	--init debug
	local debugPort = tonumber(skynet.getenv("debugport")) or 0
	if debugPort > 0 then
		skynet.newservice("debug_console",debugPort)
	end

	--init lua server
	initLogicLuaService(selfNodeName)

	--init cluster node
	SM.monitor_subscribe.req.connectMonitorAndPush(selfNodeName)
	cluster.open(selfNodeName)
	
	skynet.exit()
end)