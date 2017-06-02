-- @Author: linfeng
-- @Date:   2017-02-07 15:16:26
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-31 10:35:45

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "snax"
local cluster = require "cluster"

local monitorNodeName

function init( ... )
	snax.enablecluster()
	monitorNodeName = assert(skynet.getenv("monitornode"))
end

function exit( ... )
	-- body
end

function response.connectMonitorAndPush( selfNodeName )
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
end

function response.syncClusterInfo( clusterInfo )
	--reload clustername.lua
	SM.rpc.req.updateClusterName(clusterInfo)
end