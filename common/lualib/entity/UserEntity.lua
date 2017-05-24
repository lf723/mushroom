-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-23 15:16:18
local skynet = require "skynet"
require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义UserEntity类型
UserEntity = class(Entity)

function UserEntity:ctor()

end

function UserEntity:Init()
	
end

function UserEntity:dtor()
end

function UserEntity:GetKey(row)
	return row[self.key]
end


-- 加载玩家数据
function UserEntity:Load(uid)
	if not self.recordset[uid] then
		local row = EntityImpl:LoadUser(self.tbname, uid)
		if not table.empty(row) then
			self.recordset[uid] = row
		end
	end

end

-- 从DB重新同步数据
function UserEntity:ReLoad(uid)

end

-- 卸载玩家数据
function UserEntity:UnLoad(uid)
	local rs = self.recordset[uid]
	if rs then
		for k, v in pairs(rs) do
			rs[k] = nil
		end
		self.recordset[uid] = nil

		--设置redis的内容60分钟后失效,to do

	end
end

-- row中包含self.pkfield字段（如果表主键是self.pkfield字段，不需要包含）,row为k,v形式table
-- 内存中不存在，则添加，并同步到redis
function UserEntity:Add(row, nosync)
	if row[self.key] and self.recordset[row[self.key]] then
		LOG_ERROR("Add UserEntity error,had exists,%s",tostring(row))
		return false -- 记录已经存在，返回
	end		

	local id = row[self.key]
	if not id or id == 0 then
		id = self:GetNextId()
		row[self.key] = id
	end

	local ret = EntityImpl:AddUser(self.tbname, row)
	if ret then
		row[self.key] = id
		self.recordset[row[self.key]] = row
	end

	return ret
end

-- row中包含[self.key]字段,row为k,v形式table
-- 从内存中删除，并同步到redis
function UserEntity:Delete(row, nosync)
	if not row[self.key] then
		LOG_ERROR("Delete UserEntity,row not [%s] field,%s",self.key,tostring(row))
		return
	end
	
	local ret = EntityImpl:DelUser(self.tbname, row)
	if ret then 
		self.recordset[row[self.key]] = nil
	end

	return ret
end

-- row中包含[self.key]字段,row为k,v形式table
-- 仅从内存中移除，但不同步到redis
function UserEntity:Remove(row)
	if not row[self.key] or not self.recordset[row[self.key]] then
		LOG_ERROR("Remove UserEntity,not exists,%s",tostring(row))
		return 
	end		-- 记录不存在，返回
	self.recordset[row[self.key]] = nil

	return true
end

-- row中包含[self.key]字段,row为k,v形式table
function UserEntity:Update(row, nosync)

	local update_local = true
	if not row[self.key] then
		assert(false,self.key.." not exists")
	end
	if not self.recordset[row[self.key]] then
		update_local = false
	end		-- 记录不存在，离线玩家，不需要更新内存

	local ret = EntityImpl:UpdateUser(self.tbname, row)
	if ret and update_local then
		for k, v in pairs(row) do
			if self.recordset[row[self.key]] then
				self.recordset[row[self.key]][k] = v
			end
		end
	end

	return ret
end

function UserEntity:Get(uid, field)
	-- 内存中存在
	local record

	if self.recordset[uid] then
		if type(field) == "string" then
			record = self.recordset[uid][field]
		elseif type(field) == "table" then
			record = {}
			for i=1, #field do
				local t = self.recordset[uid]
				record[field[i]] = t[field[i]]
			end
		else
			record = self.recordset[uid]
		end
		return record
	end

	record = EntityImpl:LoadUser(self.tbname, uid)

	if type(field) == "string" then
		return record[orifield]
	elseif type(field) == "table" then
		local ret = {}
		for _,v in pairs(field) do
			ret[v] = record[v]
		end
		return ret
	end
end

-- field为字符串表示获取单个字段的值
-- field为一个数组形式table，表示获取数组中指定的字段的值，返回k,v形式table
function UserEntity:GetValue(uid, field)
	if not field then return end
	local record = self:Get(uid, field)
	if record then
		return record
	end
end

-- 成功返回true，失败返回false或nil
-- 设置单个字段的值，field为字符串，value为值
-- 设置多个字段的值，field为k,v形式table，

-- 设置单个字段的值，field为string，data为值，设置多个字段的值,field为key,value形式table,value为空
function UserEntity:SetValue(uid, field, value)
	local record = {}
	record[self.pkfield] = uid
	if value then
		record[field] = value
	else
		for k, v in pairs(field) do
			record[k] = v
		end
	end

	return self:Update(record)
end
