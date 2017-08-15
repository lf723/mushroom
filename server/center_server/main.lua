-- @Author: linfeng
-- @Date:   2017-01-19 15:51:06
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:14:57

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local EntityImpl = require "EntityImpl"

local function initLogicLuaService( selfNodeName )
	--init entity config to sharedata
	EntityImpl:SetEntityCfg(ConfigEntityCfg, CommonEntityCfg, UserEntityCfg)

	--unique route
	snax.uniqueservice("route")
end

skynet.start(function ( ... )
	
	local selfNodeName = skynet.getenv("clusternode") .. skynet.getenv("serverid")
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