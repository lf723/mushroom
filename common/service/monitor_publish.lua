-- @Author: linfeng
-- @Date:   2017-02-07 17:08:20
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-08 10:55:57

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "snax"
local cluster = require "cluster"

local clusterInfo = {}
local thisNodeName
function init( selfNodeName )
	snax.enablecluster()
	if selfNodeName then
		thisNodeName = selfNodeName
		-- init self cluster info
		clusterInfo[selfNodeName] = { ip = skynet.getenv("clusterip"), port = tonumber(skynet.getenv("clusterport"))}
		SM.rpc.req.updateClusterName(clusterInfo)
	end
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
			SM.rpc.req.RpcCall(name,"monitor_subscribe", "syncClusterInfo", clusterInfo)
		end
	end

	--return cluster info to remoteName node
	return clusterInfo
end