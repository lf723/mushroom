-- @Author: linfeng
-- @Date:   2017-06-07 14:29:14
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:14:55

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "skynet.snax"
local cluster = require "skynet.cluster"

local UserRoute = {}

function init( ... )
	snax.enablecluster()
end

function exit( ... )
	-- body
end

function response.GetUserSvr( uid )
	print("response.GetUserSvr...")
	if UserRoute[uid] then
		return UserRoute[uid]
	else
		--查询位于哪个db
		local dbClusterNodes = GetClusterNodeByName("db", true)
		local ret
		for _,v in pairs(dbClusterNodes) do
			ret = RpcCall(v, REMOTE_SERVICE, REMOTE_CALL, "user", "Get", iggid)
			if ret then
				UserRoute[uid] = {}
				UserRoute[uid].dbserver = v --cache result
				break 
			end
			ret = nil
		end

		return UserRoute[uid]
	end
end