-- @Author: linfeng
-- @Date:   2017-01-19 15:25:15
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-25 15:55:42

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local cluster = require "cluster"
local EntityImpl = require "EntityImpl"
require "dbcfg"

local function initLogicLuaService( selfNodeName )
	--init entity config to sharedata
	EntityImpl:SetEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg)
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
	local debugPort = tonumber(skynet.getenv("debug_port")) or 0
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