-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-17 17:17:36
local skynet = require "skynet"
local LoadEntity = require "LoadEntity"
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
	local rs = LoadEntity.LoadConfig(self.tbname)
	if rs then
		self.recordset = rs
	end
end

function ConfigEntity:Unload()
	self.recordset = nil
end

function ConfigEntity:Get(...)
	local t = { ... }
	assert(#t > 0)
	local key
	if #t == 1 then
		key = t[1]
	else
		key = ""
		for i = 1, #t do
			if i > 1 then
				key = key .. ":"
			end
			key = key .. tostring(t[i])
		end
	end

	return self.recordset[key] or {}
end


function ConfigEntity:GetAll( )
	return self.recordset
end