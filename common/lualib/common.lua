-- @Author: linfeng
-- @Date:   2017-05-18 11:18:27
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-23 14:33:49

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

function TableUnpackToString( tb )
	local ret = ""
	for k,v in pairs(tb) do
		ret = ret .. k .. " " .. v .." "
	end
	return ret
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