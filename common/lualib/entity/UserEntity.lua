-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-27 18:03:51
local skynet = require "skynet"
require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义UserEntity类型
UserEntity = class(Entity)

function UserEntity:ctor()

end

function UserEntity:Init()
	self.dbNode = {} --当存在dbNode时,不直接从redis or db读取数据,而是从相应的dbNode节点获取
end

function UserEntity:dtor()
end

function UserEntity:GetKey(row)
	return row[self.key]
end

-- 加载玩家数据
function UserEntity:Load(uid, dbNode)
	if not self.recordset[uid] then
		local row = EntityImpl:LoadUser(self.tbname, uid, dbNode)
		if row and not table.empty(row) then
			self.recordset[uid] = row
			self.dbNode[uid] = dbNode
		end
	end
end

-- 卸载玩家数据
function UserEntity:UnLoad(uid)
	local rs = self.recordset[uid]
	if rs then
		if self.dbNode[uid] then
			--同步到dbNode
			RpcSend(self.dbNode[uid], REMOTE_DB_SERVICE, REMOTE_SEND, self.tbname, "UnLoad", uid, self.recordset[uid])
		else
			--设置redis的内容60分钟后失效
			RedisExcute(string.format("expire %s:%d %d",self.tbname, uid, REDIS_EXPIRE_INTERVAL))
		end

		self.recordset[uid] = nil
		self.dbNode[uid] = nil
	end
end

-- row中包含self.indexkey字段（如果表主键是self.indexkey字段,不需要包含）,row为k,v形式table
function UserEntity:Add( row, dbNode )
	local uid = assert(row[self.indexkey])
	if uid and self.recordset[uid] then
		LOG_ERROR("Add UserEntity Error,Exists,%s",tostring(row))
		return false --记录已经存在，返回
	end

	if uid and dbNode then
		--同步到dbNode
		local ret,id,data = RpcCall(self.dbNode[uid], REMOTE_DB_SERVICE, REMOTE_CALL, self.tbname, "Add", row)
		self.recordset[uid] = data
		self.dbNode[uid] = dbNode
	else
		
		local id = self:GetNextId()
		local ret = EntityImpl:AddUser(self.tbname, id, row)
		if ret then
			row[self.key] = id
			self.recordset[uid] = row
		end
		return ret,id,row
	end
	
end

-- row中包含[self.indexkey]字段,row为k,v形式table
function UserEntity:Delete( row )
	local uid = row[self.indexkey]
	if not uid then
		LOG_ERROR("Delete UserEntity,row not [%s] field,%s",self.indexkey,tostring(row))
		return
	end
	
	local ret
	if self.dbNode[uid] then
		ret = RpcSend( self.dbNode[uid], REMOTE_DB_SERVICE, REMOTE_SEND, self.tbname, "Delete", row)
	else
		ret = EntityImpl:DelUser(self.tbname, row)
	end

	if ret then 
		self.recordset[uid] = nil
	end
	return ret
end


-- row中包含[self.indexkey]字段,row为k,v形式table
function UserEntity:Update(row, remoteNode)
	local update_local = true
	local uid = row[self.indexkey]
	if not uid then
		assert(false,self.indexkey.." Not Exists")
	end
	if not self.recordset[uid] then
		update_local = false
	end		-- 记录不存在，离线玩家，不需要更新内存

	local ret
	if not update_local or self.dbNode[uid] then
		local remoteNode = update_local and remoteNode or self.dbNode[uid]
		ret = RpcCall( remoteNode, REMOTE_DB_SERVICE, REMOTE_CALL, self.tbname, "Update", row)
	else
		ret = EntityImpl:UpdateUser(self.tbname, row)
	end

	if ret and update_local then
		for k, v in pairs(row) do
			if self.recordset[uid] then
				self.recordset[uid][k] = v
			end
		end
	end
	return ret
end

function UserEntity:Get(uid, field)
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

	--memory not exist
	record = EntityImpl:LoadUser(self.tbname, uid)
	if record then
		if type(field) == "string" then
			return record[field]
		elseif type(field) == "table" then
			local ret = {}
			for _,v in pairs(field) do
				ret[v] = record[v]
			end
			return ret
		else
			return record[uid]
		end
	end
end

-- field为字符串表示获取单个字段的值
function UserEntity:GetValue(uid, field)
	if not field then return end
	local record = self:Get(uid, field)
	if record then
		return record
	end
end

-- 成功返回true，失败返回false或nil
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
