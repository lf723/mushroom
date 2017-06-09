-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-06 13:51:24
local skynet = require "skynet"
local EntityImpl = require "EntityImpl"
require "Entity"

-- 定义ConfigEntity类型
ConfigEntity = class(Entity)

function ConfigEntity:ctor()

end

function ConfigEntity:dtor()

end

function ConfigEntity:Init()

end

function ConfigEntity:Load()
	local rs = EntityImpl:LoadConfig(self.tbname)
	if rs then
		self.recordset = rs
	end
end

function ConfigEntity:Unload()
	self.recordset = nil
end

function ConfigEntity:Get( key, fields )
	if not fields then
		return self.recordset[key]
	elseif type(fields) == "table" then
		local ret = {}
		for _,v in pairs(fields) do
			ret[v] = self.recordset[key][v]
		end
		return ret
	elseif type(fields) == "string" then
		return self.recordset[key][fields]
	end
end


function ConfigEntity:GetAll( )
	return self.recordset
end