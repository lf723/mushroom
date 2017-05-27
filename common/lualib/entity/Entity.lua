-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-27 17:53:00
local skynet = require "skynet"

-- 定义Entity类型
Entity = class()

function Entity:ctor()
	self.recordset = {}			-- 存放记录集
	setmetatable(self.recordset, { __mode = "k" }) --key弱表
	self.tbname = ""			-- 表名
	self.key = ""				-- 主键
	self.indexkey = ""			-- 索引
end

-- 获取redis下一个编号
function Entity:GetNextId()
	local id = RedisExcute(string.format("incr %s:%s", self.tbname, self.key ))
	if id == 1 then
		id = tonumber(skynet.getenv("serverid")) * 10000000
		RedisExcute( string.format("set %s:%s %d", self.tbname , self.key, id))
	end
	return id
end

function Entity:dtor()
	
end


local M = {}
local entities = {}		-- 保存实体对象

-- 工厂方法，获取具体对象，name为表名
function M.Get(name)
	if entities[name] then
		return entities[name]
	end

	local ent = require(name)
	entities[name] = ent
	return ent
end

return M
