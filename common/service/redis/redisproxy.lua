-- @Author: linfeng
-- @Date:   2017-02-09 15:12:54
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-18 09:23:49

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"

local redisAgentSvrs = {}
local redisAgentNum

local function initRedisAgent( ... )
	redisAgentNum = skynet.getenv("redisagent_num")

	for i=1,redisAgentNum do
		table.insert(redisAgentSvrs,assert(snax.newservice("redisagent")))
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
	local index = (routeIndex or 0) % redisAgentNum
	return redisAgentSvrs[index]
end