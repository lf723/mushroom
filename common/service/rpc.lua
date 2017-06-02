-- @Author: linfeng
-- @Date:   2017-01-10 15:14:06
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-01 17:12:46

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local cluster = require "cluster"
local sharedata = require "sharedata"

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
		f:write(name.."=\""..node.ip..":"..node.port.."\"\n")
	end
	f:close()
	cluster.reload()

	sharedata.update(SHARE_CLUSTER_CFG, clusterInfo)
end

function response.RemoteCall( tbname, method, ... )
	return SM[tbname].req[method](...)
end

function accept.RemoteSend( tbname, method, ... )
	SM[tbname].req[method](...)
end

function response.GetClusterCfg( ... )
	return sharedata.query( SHARE_CLUSTER_CFG)
end

function init( ... )
	--new cluster node shared data
	sharedata.new(SHARE_CLUSTER_CFG, {})
	snax.enablecluster()
end

function exit( ... )
	sharedata.delete(SHARE_CLUSTER_CFG)
end