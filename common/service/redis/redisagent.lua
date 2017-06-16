-- @Author: linfeng
-- @Date:   2017-02-09 15:13:21
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-15 15:04:43

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local redis = require "redis"

local redisInstance

function init( conf )
	--connect to redis
	redisInstance = assert(redis.connect(conf),tostring(conf))
	redisInstance:flushdb()
end

function exit( ... )
	if redisInstance then redisInstance:disconnect() end
end

function response.Do( cmd, pipeline )
	local ok,ret
	if pipeline then
		assert(type(cmd) == "table", tostring(cmd))
		for k,v in pairs(cmd) do
			cmd[k] = string.split(v, " ")
		end
		ok,ret = pcall(redisInstance.pipeline, redisInstance, cmd, {} ) --offer a {} for result
		if not ok then
			--retry,if disconnect, will auto reconnect at socketchannel in last query
			ret = redisInstance:pipeline( cmd, {} )
		end
	else
		local args = string.split(cmd," ")
		local redisCmd = args[1]
		table.remove(args,1)
		ok,ret = pcall(redisInstance[redisCmd], redisInstance, table.unpack(args))
		if not ok then
			--retry,if disconnect, will auto reconnect at socketchannel in last query
			ret = redisInstance[redisCmd](redisInstance, table.unpack(args))
		end
	end
	return ret
end