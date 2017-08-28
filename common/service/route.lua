-- @Author: linfeng
-- @Date:   2017-06-07 14:29:14
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:14:51

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
	if UserRoute[uid] then
		return UserRoute[uid].dbserver
	else
		local ret
		--查询位于哪个db
		local dbClusterNodes = GetClusterNodeByName("db", true)
		if dbClusterNodes then
			for _,v in pairs(dbClusterNodes) do
				ret = RpcCall(v, REMOTE_SERVICE, REMOTE_CALL, "d_charactor", "Get", uid)
				if ret then
					UserRoute[uid] = {}
					UserRoute[uid].dbserver = v --cache result
					ret = v
					break 
				end
				ret = nil
			end
		end

		return ret
	end
end

function response.test( ... )
	print(snax.self())
end