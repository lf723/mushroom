-- @Author: linfeng
-- @Date:   2016-11-25 18:21:47
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-09 14:53:17

local skynet = require "skynet"
require "skynet.manager"
local cluster = require"cluster"
local snax = require "snax"

local function initLogicLuaService( ... )
	-- body
end

skynet.start(function ()
	local selfNodeName = "game"..skynet.getenv("serverid")
	--init log
	snax.uniqueservice("syslog", selfNodeName)

	--init web
	local webPort = tonumber(skynet.getenv("webport")) or 0
	if webPort > 0 then
		skynet.uniqueservice("web", webPort)
	end

	--init debug
	local debugPort = tonumber(skynet.getenv("debug_port")) or 0
	if debugPort > 0 then
		skynet.newservice("debug_console",debugPort)
	end

	--init cluster node
	SM.monitor_subscribe.req.connectMonitorAndPush(selfNodeName)
	cluster.open(selfNodeName)

	--init lua server
	initLogicLuaService()

	--init gate(begin listen)
	local gated = skynet.uniqueservice("gated")
	skynet.call(gated, "lua", "open", 
									{
										port = tonumber(skynet.getenv("port")) or 8888,
										maxclient = tonumber(skynet.getenv("maxclient")) or 1024,
										servername = selfNodeName,
									}
	)

	--exit
	skynet.exit()
end)