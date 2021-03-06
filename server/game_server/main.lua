-- @Author: linfeng
-- @Date:   2016-11-25 18:21:47
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:34:24

local skynet = require "skynet"
require "skynet.manager"
local cluster = require"skynet.cluster"
local snax = require "skynet.snax"
local EntityImpl = require "EntityImpl"
require "gamecfg"

local function initLogicLuaService( ... )
	--init entity config to sharedata
	EntityImpl:SetEntityCfg( ConfigEntityCfg, CommonEntityCfg, UserEntityCfg )

	--load Config
	SM.loaddata.req.Load( TB_CONFIG )
end

skynet.start(function ()
	local selfNodeName = skynet.getenv("clusternode")..skynet.getenv("serverid")
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

	--init lua server
	initLogicLuaService()

	--init cluster node
	SM.monitor_subscribe.req.connectMonitorAndPush(selfNodeName)
	cluster.open(selfNodeName)

	--init gate(begin listen)
	local gamed = skynet.uniqueservice("gamed")
	skynet.call(gamed, "lua", "open", 
									{
										port = tonumber(skynet.getenv("port")) or 8888,
										maxclient = tonumber(skynet.getenv("maxclient")) or 1024,
										servername = selfNodeName,
									}
	)

	--exit
	skynet.exit()
end)