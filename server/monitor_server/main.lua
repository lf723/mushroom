-- @Author: linfeng
-- @Date:   2017-01-19 15:48:21
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:34:30

local skynet = require "skynet"
require "skynet.manager"
local cluster = require"skynet.cluster"
local snax = require "skynet.snax"

local function initLogicLuaService( selfNodeName )
	snax.uniqueservice("monitor_publish", selfNodeName)
end

skynet.start(function ( ... )
	local selfNodeName = skynet.getenv("clusternode")
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
	cluster.open(selfNodeName)
	
	skynet.exit()
end)
