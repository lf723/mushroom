-- @Author: linfeng
-- @Date:   2017-05-18 11:18:27
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-20 16:01:18

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "snax"

function MySqlExecute( sql, routeIndex, sync )
	local mysqlHandle, mysqlName = SM.mysqlproxy.req.route(routeIndex)
	if not mysqlHandle then
		assert(false,"no mysql connect instance alive,MySqlExecute error")
	end

	local obj = snax.bind(mysqlHandle, mysqlName)
	return obj.req.query(sql)
end

function CheckMysqlResult( ret )
	local errIndex = {}
	for k,v in pairs(ret) do
		if v.badresult ~= nil then
			errIndex[k] = v.badresult
		end
	end
	return #errIndex <= 0, errIndex
end

function RedisExecute( cmd, routeIndex, pipeline, resp )
	local redisHandle, redisName = SM.redisproxy.req.route(routeIndex)
	if not redisHandle then
		assert(false,"no redis connect instance alive,DoRedis error")
	end

	local obj = snax.bind(redisHandle, redisName)
	return obj.req.Do(cmd, pipeline, resp)
end

function RpcCall( node, svrname, method, ... )
	local remoteHandle,remoteSvrName = SM.rpc.req.RemoteSvr(node, svrname)
	if remoteHandle then
		local obj = snax.bind(remoteHandle, remoteSvrName)
		local ok,ret = pcall(obj.req[method], ...)
		if not ok then 
			LOG_ERROR("RpcCall %s-%s-%s Fail->%s", node, svrname, method, ret)  
			return nil 
		end
		return ret
	else
		LOG_SKYNET("RpcCall,snax remote node:%s svr:%s fail", node, svrname)
		return nil
	end
end

function RpcSend( node, svrname, method, ... )
	local remoteHandle,remoteSvrName = SM.rpc.req.RemoteSvr(node, svrname)
	if remoteHandle then
		local obj = snax.bind(remoteHandle, remoteSvrName)
		local ok,ret = pcall(obj.post[method],...)
		if not ok then 
			LOG_ERROR("RpcCall Fail->%s",ret)  
			return nil 
		end
		return ret
	else
		LOG_SKYNET("RpcCall,snax remote node:%s svr:%s fail", node, svrname)
		return nil
	end
end

function TableUnpackToString( tb )
	local ret = ""
	for k,v in pairs(tb) do
		ret = ret .. k .. " " .. v .." "
	end
	return ret
end

function TableValueConvertToNumber( tb )
	for k,v in pairs(tb) do
		tb[k] = tonumber(v) or v
	end
end

function GetTableValueByIndex( tb, index )
	assert(index >= 1, "index must >= 1 at GetTableValueByIndex")
	local i = 1
	for k,v in pairs(tb) do
		if i == index then
			return v
		end

		i = i + 1
	end
end

function ConvertIpairToKv( tb )
	assert(type(tb) == "table" and #tb %2 == 0)
	local ret = {}
	for i=1,#tb,2 do
		ret[tb[i]] = tb[i+1]
	end
	return ret
end

function GetClusterNodeByName( name, fuzzy )
	local clusterInfo = SM.rpc.req.GetClusterCfg()
	local ret
	if clusterInfo then
		for nodeName,_ in pairs(clusterInfo) do
			if fuzzy then
				if nodeName:find(name) ~= nil then
					if not ret then ret = {} end
					table.insert(ret, nodeName)
				end
			else
				if nodeName == name then
					ret = nodeName
					break
				end
			end
		end
	end

	return ret
end
