-- @Author: linfeng
-- @Date:   2017-02-20 15:53:38
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:12:19

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"

local mysqlAgentSvrs = {}
local mysqlAgentNum

local function initMysqlAgent( ... )
	mysqlAgentNum = skynet.getenv("dbagentnum") or 10

	for i=1,mysqlAgentNum do
		table.insert(mysqlAgentSvrs,assert(snax.newservice("mysqlagent")))
	end
end

local function exitMysqlAgent( ... )
	for _,mysqlObj in pairs(mysqlAgentSvrs) do
		snax.kill(mysqlObj)
	end
end

function init( ... )
	initMysqlAgent() 
end

function exit( ... )
	exitMysqlAgent()
end

-- brief : 根据uid路由到一个mysql实例
-- param : routeIndex,路由的index,如果为nil,则总是路由到第一个实例
-- return : mysqlagent server instance,避免单节点设计
function response.route( routeIndex )
	local index = (routeIndex or 1) % mysqlAgentNum + 1
	return mysqlAgentSvrs[index].handle, "mysqlagent"
end