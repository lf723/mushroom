-- @Author: linfeng
-- @Date:   2017-02-20 15:53:38
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:12:14

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"

local mongodbAgentSvrs = {}
local mongodbAgentNum

local function initMongoDbAgent( ... )
	mongodbAgentNum = skynet.getenv("mongodbagent_num")

	for i=1,mongodbAgentNum do
		table.insert(mongodbAgentSvrs,assert(snax.newservice("mongoagent")))
	end
end

local function exitMongoDbAgent( ... )
	for _,mongodbObj in pairs(mongodbAgentSvrs) do
		snax.kill(mongodbObj)
	end
end

function init( ... )
	initMongoDbAgent()
end

function exit( ... )
	exitMongoDbAgent()
end

-- brief : 根据uid路由到一个mongodb实例
-- param : routeIndex,路由的index,如果为nil,则总是路由到第一个实例
-- return : mongodbagent server instance,避免单节点设计
function response.route( routeIndex )
	local index = routeIndex % mongodbAgentNum
	return mongodbAgentSvrs[index]
end