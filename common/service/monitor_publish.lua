-- @Author: linfeng
-- @Date:   2017-02-07 17:08:20
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-07-11 14:49:45

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "snax"
local cluster = require "cluster"

local clusterInfo = {}
local thisNodeName
local heartError = {}
local heartCo

local function ClusterHold( ... )
	local CheckStr = "check"
	while true do
		skynet.sleep(3 * 100)
		local sync = false
		for node,info in pairs(clusterInfo) do
			if node ~= thisNodeName then
				if RpcCall( node, "monitor_subscribe", "Heart", CheckStr) ~= CheckStr then
					if not heartError[node] then 
						heartError[node] = 1 
					else 
						clusterInfo[node] = nil
						heartError[node] = nil
						sync = true
					end
				end
			end
		end

		if sync then
			SM.rpc.req.updateClusterName(clusterInfo)
			for node,info in pairs(clusterInfo) do
				RpcCall(node,"monitor_subscribe", "syncClusterInfo", clusterInfo)
			end
		end
	end
end

function init( selfNodeName )
	snax.enablecluster()
	if selfNodeName then
		thisNodeName = selfNodeName
		-- init self cluster info
		local ip = skynet.getenv("clusterip")
		local port = skynet.getenv("clusterport")
		clusterInfo[selfNodeName] = { ip = ip, port = tonumber(port)}

		--init clustername.lua
		local f = io.open("etc/clustername.lua","w+")
		f:write(thisNodeName.. "=" .. ip .. ":" .. port)
		f:flush()
		f:close()

		SM.rpc.req.updateClusterName(clusterInfo)
	end

	heartCo = skynet.fork(ClusterHold)
end

function exit( ... )
	-- body
end

-- brief : 从其他服务节点请求,用于提交自己的节点信息,并返回整个集群的cluster info
-- param : name, 名称
-- param : ip, 地址
-- param : port, 端口
-- return : 整个分布集群的cluster info, eg: clusterinfo = { monitor = { ip = "127.0.0.1", port = 7000}, ... }
function response.sync( remoteName, remoteIp, remotePort )
	clusterInfo[remoteName] = { ip = remoteIp, port = tonumber(remotePort)}
	SM.rpc.req.updateClusterName(clusterInfo)

	--notify all other cluster node,update cluster info
	for name,_ in pairs(clusterInfo) do
		if name ~= thisNodeName and name ~= remoteName then
			RpcCall(name,"monitor_subscribe", "syncClusterInfo", clusterInfo)
		end
	end

	--return cluster info to remoteName node
	return clusterInfo
end

function response.Heart( ... )
	return ...
end
