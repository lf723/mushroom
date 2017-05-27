-- @Author: linfeng
-- @Date:   2017-02-09 15:12:54
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-25 15:16:20

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"

local redisAgentSvrs = {}
local redisAgentNum

local function initRedisAgent( ... )
	redisAgentNum = skynet.getenv("redisnum") or 10

	local conf = {
		host = skynet.getenv("redisip"),
		port = tonumber(skynet.getenv("redisport")),
		auth = skynet.getenv("redisauth"),
		db = tonumber(skynet.getenv("redisdb")) or 0
	}

	for i=1,redisAgentNum do
		table.insert(redisAgentSvrs,assert(snax.newservice("redisagent",conf)))
		conf.port = conf.port + 1
	end
end

local function exitRedisAgent( ... )
	for _,redisObj in pairs(redisAgentSvrs) do
		snax.kill(redisObj)
	end
end

function init( ... )
	initRedisAgent()
end

function exit( ... )
	exitRedisAgent()
end

-- brief : 根据uid路由到一个redis实例
-- param : routeIndex,路由的index,如果为nil,则总是路由到第一个实例
-- return : redisagent server instance,避免单节点设计
function response.route( routeIndex )
	local index = (routeIndex or 1) % redisAgentNum
	return redisAgentSvrs[index].handle, "redisagent"
end