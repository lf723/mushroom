-- @Author: linfeng
-- @Date:   2016-11-24 18:20:33
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:14:59

local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"
local snax = require "skynet.snax"

local function initLogicLuaService( selfNodeName )

end

skynet.start(function ( ... )
	local selfNodeName = skynet.getenv("clusternode").. skynet.getenv("serverid")
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

	--init cluster node
	SM.monitor_subscribe.req.connectMonitorAndPush(selfNodeName)
	cluster.open(selfNodeName)

	--init lua server
	initLogicLuaService(selfNodeName)

	--init login gate
	skynet.uniqueservice("logind")
	
	skynet.exit()
end)