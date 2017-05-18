-- @Author: linfeng
-- @Date:   2017-05-18 11:18:27
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-18 14:38:21

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math

function MySqlExecute( sql, routeIndex, sync )
	local mysqlInstance = SM.mysqlproxy.req.route(routeIndex)
	if not mysqlInstance then
		assert(false,"no mysql connect instance alive,MySqlExecute error")
	end

	return mysqlInstance.req.query(sql)
end

function RedisExecute( cmd, routeIndex )
	local redisInstance = SM.redisproxy.req.route(routeIndex)
	if not redisInstance then
		assert(false,"no redis connect instance alive,DoRedis error")
	end

	return redisInstance.req.Do(cmd)
end

function TableUnpackToString( tb )
	local res = ""
	for k,v in pairs(tb) do
		ret = ret .. k .. " " .. v .." "
	end
	return res
end