-- @Author: linfeng
-- @Date:   2017-06-07 14:29:14
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-08 11:04:35

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "snax"
local cluster = require "cluster"

local UserRoute = {}

function init( ... )
	snax.enablecluster()
end

function exit( ... )
	-- body
end

function response.GetUserSvr( uid )
	if UserRoute[uid] then
		return UserRoute[uid].dbserver
	else
		--查询位于哪个db
		local dbClusterNodes = GetClusterNodeByName("db", true)
		local ret
		for _,v in pairs(dbClusterNodes) do
			ret = RpcCall(v, REMOTE_SERVICE, REMOTE_CALL, "user", "Get", uid)
			if ret then
				UserRoute[uid] = {}
				UserRoute[uid].dbserver = v --cache result
				break 
			end
			ret = nil
		end
		if ret then
			return UserRoute[uid].dbserver
		else
			return ret
		end
	end
end