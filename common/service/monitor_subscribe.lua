-- @Author: linfeng
-- @Date:   2017-02-07 15:16:26
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-07-11 10:40:46

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "snax"
local cluster = require "cluster"

local monitorNodeName
local thisNodeName

local function ClusterHold( ... )
	local CheckStr = "check"
	while true do
		skynet.sleep(3 * 100) --check per 3s
		if RpcCall(monitorNodeName, "monitor_publish", "Heart", CheckStr) ~= CheckStr then
			--reconnect
			snax.self().req.connectMonitorAndPush( thisNodeName, true )
		end
	end
end

function init( ... )
	snax.enablecluster()
	monitorNodeName = assert(skynet.getenv("monitornode"))
end

function exit( ... )
	-- body
end

function response.connectMonitorAndPush( selfNodeName, noFork )
	thisNodeName = selfNodeName
	local ok = false
	local clusterInfo
	local clusterIp = assert(skynet.getenv("clusterip"))
	local clusterPort = assert(skynet.getenv("clusterport"))
	while not clusterInfo do
		clusterInfo = RpcCall(monitorNodeName, "monitor_publish", "sync", selfNodeName, clusterIp, clusterPort)
		skynet.sleep(100)
	end

	--reload clustername.lua
	SM.rpc.req.updateClusterName(clusterInfo)

	--hold cluster connect
	if not noFork then
		skynet.fork(ClusterHold)
	end
end

function response.syncClusterInfo( clusterInfo )
	--reload clustername.lua
	SM.rpc.req.updateClusterName(clusterInfo)
end

function response.Heart( ... )
	return ...
end