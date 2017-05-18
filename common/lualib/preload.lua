-- @Author: linfeng
-- @Date:   2017-02-06 17:39:27
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-18 11:27:12

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local string = string
local table = table
local math = math

require "luaext"
require "logdef"
require "enum"
require "common"

--获取保存SM的元表,server不存在时，会自动uniqueservice
function GetSmMetaTable()
	local t = {}
	return setmetatable(t,{ __index = function ( self, key )
		local obj = snax.uniqueservice(key)
		self[key] = obj
		return obj
	end})
end

SM = GetSmMetaTable()

LOG_PATH = skynet.getenv("logpath")
EVENT_LOG_PATH = skynet.getenv("eventlogpath")

--使用的数据库
G_DBTYPE = skynet.getenv("db")