-- @Author: linfeng
-- @Date:   2015-06-17 09:49:05
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-08 13:51:40
local skynet = require "skynet"
require "Entity"
local EntityImpl = require "EntityImpl"
-- 定义UserEntity类型
UserEntity = class(Entity)

function UserEntity:ctor()

end

function UserEntity:Init()
	self.dbNode = {} --当存在dbNode时,不直接从redis or db读取数据,而是从相应的dbNode节点获取
	local ret = assert(EntityImpl:GetEntityCfg( TB_USER, self.tbname ))
	self.key = ret.key
	self.indexkey = ret.indexkey
	self.value = ret.value
	self.updateflag = {}
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
		end
		self.dbNode[uid] = dbNode
	end

	if not dbNode and self.recordset[uid] then return self.recordset[uid] end
end

-- 卸载玩家数据
function UserEntity:UnLoad(uid, row)
	local rs = self.recordset[uid]
	if rs then
		if self.dbNode[uid] and self.updateflag[uid] then
			--同步到dbNode
			RpcSend(self.dbNode[uid], REMOTE_SERVICE, REMOTE_SEND, self.tbname, "UnLoad", uid, self.recordset[uid])
		else
			if row then self:Update( row ) end --先更新
			--设置redis的内容60分钟后失效
			RedisExecute(string.format("expire %s:%d %d",self.tbname, uid, REDIS_EXPIRE_INTERVAL))
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
		local ret,id,data = RpcCall(dbNode, REMOTE_SERVICE, REMOTE_CALL, self.tbname, "Add", row)
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
		ret = RpcSend( self.dbNode[uid], REMOTE_SERVICE, REMOTE_SEND, self.tbname, "Delete", row)
	else
		ret = EntityImpl:DelUser(self.tbname, row)
	end

	if ret then 
		self.recordset[uid] = nil
	end
	return ret
end


-- row中包含[self.indexkey]字段,row为k,v形式table
function UserEntity:Update( row, nosync )

	local updateOffline = false
	local uid = row[self.indexkey]
	if not uid then
		assert(false,self.indexkey.." Not Exists")
	end
	if not self.recordset[uid] then
		updateOffline = true
	end

	local ret = true
	if updateOffline and not nosync then --离线玩家数据更新到DB
		local _centerserver = GetClusterNodeByName("center")
		local dbserver = RpcCall( _centerserver, "route", "GetUserSvr", uid)
		assert(dbserver, "UserEntity:Update Offline User Info, uid not exist:" .. uid)
		ret = RpcCall( dbserver, REMOTE_SERVICE, REMOTE_CALL, self.tbname, "Update", row, true)
	else
		if not self.dbNode[uid] then
			ret = EntityImpl:UpdateUser(self.tbname, row)
		end
	end

	if ret and not updateOffline then
		for k, v in pairs(row) do
			if self.recordset[uid] then
				self.recordset[uid][k] = v
			end
		end
		self.updateflag[uid] = true
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
	record = EntityImpl:LoadUser( self.tbname, uid, self.dbNode[uid] )
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
			return record
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
	record[self.indexkey] = uid
	if value then
		record[field] = value
	else
		for k, v in pairs(field) do
			record[k] = v
		end
	end

	return self:Update(record)
end