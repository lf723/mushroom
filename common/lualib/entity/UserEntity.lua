-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-18 13:58:50
local skynet = require "skynet"
require "Entity"

-- 定义UserEntity类型
UserEntity = class(Entity)

function UserEntity:ctor()
	self.ismulti = false		-- 是否多行记录
	self.keyfields = ""			-- keyfields以:分隔
	self.indexkeyfields = ""
end

function UserEntity:Init()
	self.pkfield, self.keyfields, self.indexkeyfields = DbMgrCall("get_table_key", self.tbname, TB_USER)
end

function UserEntity:dtor()
end

function UserEntity:GetKey(row)
	return row[self.pkfield]
end


-- 加载玩家数据
function UserSingleEntity:Load(uid)
	if not self.recordset[uid] then
		local row = DbMgrCall("get_user_single", self.tbname, uid)
		if not table.empty(row) then
			self.recordset[uid] = row
		end
	end

end

-- 将内存中的数据先同步回redis,再从redis加载到内存（该方法要不要待定）
function UserSingleEntity:ReLoad(uid)

end

-- 卸载玩家数据
function UserSingleEntity:UnLoad(uid)
	local rs = self.recordset[uid]
	if rs then
		for k, v in pairs(rs) do
			rs[k] = nil
		end

		self.recordset[uid] = nil

		--设置redis的内容30分钟后失效
		DbMgrCall("expire_redis", uid, 30)
	end
end

-- row中包含self.pkfield字段（如果表主键是self.pkfield字段，不需要包含）,row为k,v形式table
-- 内存中不存在，则添加，并同步到redis
function UserSingleEntity:Add(row, nosync)
	if row[self.pkfield] and self.recordset[row[self.pkfield]] then
		LOG_ERROR("Add UserSingleEntity,had exists,%s",tostring(row))
		return false
	end		-- 记录已经存在，返回

	local id = row[self.pkfield]
	if not id or id == 0 then
		id = self:GetNextId()
		row[self.pkfield] = id
	end

	local ret,newrow = DbMgrCall("add", self.tbname, row, TB_USER, nosync)
	if ret then
		self.recordset[row[self.pkfield]] = newrow
	end

	return ret
end

-- row中包含[self.pkfield]字段,row为k,v形式table
-- 从内存中删除，并同步到redis
function UserSingleEntity:Delete(row, nosync)
	if not row[self.pkfield] then
		LOG_ERROR("Delete UserSingleEntity,row not %s field,%s",self.pkfield,tostring(row))
		return
	end
	
	local ret = DbMgrCall("delete", self.tbname, row, TB_USER, nosync)
	if ret then 
		self.recordset[row[self.pkfield]] = nil
	end

	return ret
end

-- row中包含[self.pkfield]字段,row为k,v形式table
-- 仅从内存中移除，但不同步到redis
function UserSingleEntity:Remove(row)
	if not row[self.pkfield] or not self.recordset[row[self.pkfield]] then
		LOG_ERROR("Remove UserSingleEntity,not exists,%s",tostring(row))
		return 
	end		-- 记录不存在，返回
	self.recordset[row[self.pkfield]] = nil

	return true
end

-- row中包含[self.pkfield]字段,row为k,v形式table
function UserSingleEntity:Update(row, nosync)

	local update_local = true
	if not row[self.pkfield] then
		assert(false,self.pkfield.." not exists")
	end
	if not self.recordset[row[self.pkfield]] then
		update_local = false
	end		-- 记录不存在，离线玩家，不需要更新内存

	local ret = DbMgrCall("update", self.tbname, row, TB_USER, nosync)
	if ret and update_local then
		for k, v in pairs(row) do
			if self.recordset[row[self.pkfield]] then
				self.recordset[row[self.pkfield]][k] = v
			end
		end
	end

	return ret
end

-- 从内存中获取，如果不存在，说明是其他的离线玩家数据，则加载数据到redis
-- field为空，获取整行记录，返回k,v形式table
-- field为字符串表示获取单个字段的值
-- field为一个数组形式table，表示获取数组中指定的字段的值，返回k,v形式table
function UserSingleEntity:Get(uid, field)
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

	-- 从redis获取，如果redis不存在，从mysql加载
	local orifield = field
	if type(field) == "string" then
		field = { field }
	end
	
	record = DbMgrCall("get_user_single", self.tbname, uid) --不存在也返回 空的table {}

	--[[
	if not table.empty(record) then
		self.recordset[uid] = record
	end
	]]

	if type(orifield) == "string" then
		return record[orifield]
	end

	if table.empty(record) and type(orifield) == "string" then 
		LOG_ERROR("%s=%d,field=%s Get Not Found",self.pkfield,uid,orifield)
		return nil 
	end --单个不存在的时候，返回nil

	return record
end

-- field为字符串表示获取单个字段的值
-- field为一个数组形式table，表示获取数组中指定的字段的值，返回k,v形式table
function UserSingleEntity:GetValue(uid, field)
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
function UserSingleEntity:SetValue(uid, field, value)
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

--重置所有记录,包含redis和mysql
function UserSingleEntity:ResetAll(domysql)
	if domysql then
		DbMgrCall("resetall", self.tbname)
	end

	--重新load一次
	for uid,_ in pairs(self.recordset) do
		self.recordset[uid] = nil
		self:Load(uid)
	end
	
end


function UserSingleEntity:ConditionUpdate( domysql, conditiontype, conditions, rows )
	if domysql then
		DbMgrCall("condition_update", self.tbname, conditiontype, conditions, rows)
	end
	--重新load一次
	for uid,_ in pairs(self.recordset) do
		self.recordset[uid] = nil
		self:Load(uid)
	end
end