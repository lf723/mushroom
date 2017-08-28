-------------------------
--Created Date: Monday, August, 2017, 11:54:45
--Author: linfeng
--Last Modified: Thu Aug 24 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
-------------------------

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local monitorNodeName
local thisNodeName

local function ClusterHold(...)
    local CheckStr = "check"
    while true do
        skynet.sleep(10 * 100) --check per 10s
        if RpcCall(monitorNodeName, "monitor_publish", "Heart", CheckStr) ~= CheckStr then
            --reconnect
            snax.self().req.connectMonitorAndPush(thisNodeName, true)
        end
    end
end

function init(...)
    snax.enablecluster()
    monitorNodeName = assert(skynet.getenv("monitornode"))
end

function exit(...)
    -- body
end

function response.connectMonitorAndPush(selfNodeName, noFork)
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

function response.syncClusterInfo(clusterInfo)
    --reload clustername.lua
    SM.rpc.req.updateClusterName(clusterInfo)
end

function response.Heart(...)
    return ...
end
