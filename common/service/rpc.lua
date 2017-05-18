-- @Author: linfeng
-- @Date:   2017-01-10 15:14:06
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-08 15:00:31

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local cluster = require "cluster"

local string = string
local table = table
local math = math

function response.RpcCall( node, svrname, method, ... )
	local ok,snax_obj = pcall(cluster.snax, node, svrname)

	if not ok then
		LOG_ERROR("cluster snax node(%s) fail:%s",node,snax_obj)
		return nil
	end
	
	if snax_obj then
		local ok,ret = pcall(snax_obj.req[method],...)
		if not ok then 
			LOG_ERROR("RpcCall Fail->%s",ret)  
			return nil 
		end
		return ret
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
end

function init( ... )
	snax.enablecluster()
end

function exit( ... )
	-- body
end