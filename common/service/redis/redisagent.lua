-- @Author: linfeng
-- @Date:   2017-02-09 15:13:21
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-25 15:48:35

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

function response.Do( cmd, pipeline, resp )
	local ret
	if pipeline then
		assert(type(pipeline) == "table")
		ret = redisInstance:pipeline( cmd )
	else
		local args = string.split(cmd," ")
		local redisCmd = args[1]
		table.remove(args,1)
		ret = redisInstance[redisCmd](redisInstance, table.unpack(args))
	end
	return ret
end