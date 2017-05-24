-- @Author: linfeng
-- @Date:   2017-02-09 15:13:21
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-23 14:48:55

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local redis = require "redis"

local redisInstance

function init( conf )
	--connect to redis
	redisInstance assert(redis.connect(conf))
end

function exit( ... )
	if redisInstance then redisInstance:disconnect() end
end

function response.Do( cmd, pipeline, resp )
	if pipeline then
		assert(type(pipeline) == "table")
		redisInstance:pipeline( cmd )
	else
		local args = string.split(cmd," ")
		local redisCmd = args[1]
		args[1] = nil
		redisInstance[redisCmd](redisInstance, table.unpack(args))
	end
end