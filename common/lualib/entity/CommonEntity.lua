-- @Author: linfeng
-- @Date:   2015-07-01 15:42:49
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-17 16:38:11
local skynet = require "skynet"
local snax = require "snax"
require "Entity"

-- CommonEntity
CommonEntity = class(Entity)

function CommonEntity:ctor()
	-- call dbm获取key pk
	self.keyfields = ""				-- 以:分隔
	self.pkfield = ""
	self.indexkey = ""
end

function CommonEntity:Init()
	--从mysql or mongodb 加载数据
	self.pkfield, self.keyfields, self.indexkey = SM.dbMgr.req.get_table_key(self.tbname, TB_COMMON)
end

function CommonEntity:dtor()
end

-- 加载整张表数据
function CommonEntity:Load()
	local rs = SM.dbMgr.req.get_common(self.tbname)
	if rs then
		self.recordset = rs --更新内存
	end
end

-- 卸载整张表数据
function CommonEntity:UnLoad()
	self.recordset = nil
end


-- row中包含pk字段,row为k,v形式table
-- 内存中不存在，则添加，并同步到redis
function CommonEntity:Add(row, nosync)

	if row.id and self.recordset[row.id] then return end		-- 记录已经存在，返回

	local id = row[self.pkfield]
	if not id or id == 0 then
		id = self:GetNextId()
		row[self.pkfield] = id
	end

	local ret = DbMgrCall("add", self.tbname, row, TB_COMMON, nosync)

	if ret then
		local key = self:GetKey(row)
		self.recordset[key] = row
	end

	return ret,id

end


-- row中包含pk字段,row为k,v形式table
-- 从内存中删除，并同步到redis
function CommonEntity:Delete(row, nosync)
	local id = row[self.pkfield]
	if not self.recordset[id] then return end		-- 记录不存在，返回

	local ret = DbMgrCall("delete", self.tbname, row, TB_COMMON, nosync)

	if ret then
		key = self:GetKey(row)
		self.recordset[key] = nil
	end

	return true
end

-- row中包含pk字段,row为k,v形式table
-- 仅从内存中移除，但不同步到redis
function CommonEntity:Remove(row)
	local id = row[self.pkfield]
	if not self.recordset[id] then return end		-- 记录不存在，返回

	key = self:GetKey(row)
	self.recordset[key] = nil

	return true
end

-- row中包含pk字段,row为k,v形式table
function CommonEntity:Update(row, nosync)
	local id = row[self.pkfield]
	if not self.recordset[id] then return end		-- 记录不存在，返回
	

	local ret = DbMgrCall("update", self.tbname, row, TB_COMMON)

	if ret then
		key = self:GetKey(row)
		for k, v in pairs(row) do
			self.recordset[key][k] = v
		end
	end

	return true
end

function CommonEntity:Get(...)
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

--[[
function CommonEntity:Set(id, row)
	-- 设置一行记录
end
--]]

function CommonEntity:GetValue(id, field)
	local record = self:Get(id)
	
	if record and field then
		if type(field) == "string" then
			return record[field]
		elseif type(field) == "table" then
			local ret = {}
			for i=1, #field do
				ret[field[i]] = record[field[i]]
			end
			return ret
		end
	else
		return record or {}
	end
end

function CommonEntity:SetValue(id, field, data)
	local record = {}
	record[self.pkfield] = id
	record[field] = data
	return self:Update(record)
end


function CommonEntity:GetKey(row)
	local fields = string.split(self.keyfields, ",")
	local key = ""--self.tbname
	for i = 1, #fields do
		key = key .. ":" .. row[fields[i]]
	end

	key = key:trim(":")

	return tonumber(key) or key
end

function CommonEntity:GetAll( )
	return self.recordset
end
