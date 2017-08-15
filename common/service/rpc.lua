-- @Author: linfeng
-- @Date:   2017-01-10 15:14:06
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-15 09:18:18

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"
local datasheet_builder = require "skynet.datasheet.builder"
local datasheet = require "skynet.datasheet"

local string = string
local table = table
local math = math
local EntityImpl = "entity.EntityImpl"

function response.RemoteSvr( node, svrname )
	local ok,snax_obj = pcall(cluster.snax, node, svrname)
	if not ok then
		LOG_ERROR("cluster snax node(%s) fail:%s",node,snax_obj)
		return nil
	end
	
	if snax_obj then
		return snax_obj.handle, svrname
	else
		return nil
	end
end

function response.updateClusterName( clusterInfo )
	local f = io.open(skynet.getenv("cluster"),"w+")
	for name,node in pairs(clusterInfo) do
		local str = name.."=\""..node.ip..":"..node.port.."\"\n"
		f:write(str)
	end
	f:close()
	cluster.reload()

	datasheet_builder.update(SHARE_CLUSTER_CFG, clusterInfo)
end

function response.RemoteCall( service, method, ... )
	return SM[service].req[method](...)
end

function accept.RemoteSend( service, method, ... )
	SM[service].req[method](...)
end

function response.GetClusterCfg( ... )
	return datasheet.query( SHARE_CLUSTER_CFG )
end

function init( ... )
	--new cluster node shared data
	datasheet_builder.new(SHARE_CLUSTER_CFG, {})
	snax.enablecluster()
end

function exit( ... )
	datasheet_builder.delete(SHARE_CLUSTER_CFG)
end