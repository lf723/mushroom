-- @Author: linfeng
-- @Date:   2015-07-01 15:42:49
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-23 15:16:17
local skynet = require "skynet"
local snax = require "snax"
require "Entity"
local EntityImpl = require "EntityImpl"

-- CommonEntity
CommonEntity = class(Entity)

function CommonEntity:ctor()

end

function CommonEntity:Init()

end

function CommonEntity:dtor()
end

-- 加载整张表数据
function CommonEntity:Load()
	local rs = EntityImpl:LoadCommon(self.name)
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

	local ret = EntityImpl:AddCommon(self.tbname, row)
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
	local ret = EntityImpl:DelCommon(self.tbname, row)

	if ret then
		key = self:GetKey(row)
		self.recordset[key] = nil
	end

	return true
end

-- row中包含pk字段,row为k,v形式table
function CommonEntity:Update(row, nosync)
	local id = row[self.pkfield]
	if not self.recordset[id] then return end		-- 记录不存在，返回
	local ret = EntityImpl:UpdateCommon(self.tbname, row)

	if ret then
		key = self:GetKey(row)
		for k, v in pairs(row) do
			self.recordset[key][k] = v
		end
	end

	return true
end

function CommonEntity:Get(...)
	return self.recordset[self.key] or {}
end


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


function CommonEntity:GetAll( )
	return self.recordset
end
