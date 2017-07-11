-- @Author: linfeng
-- @Date:   2017-01-19 15:48:21
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-07-11 14:38:48

local skynet = require "skynet"
require "skynet.manager"
local cluster = require"cluster"
local snax = require "snax"

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
