-- @Author: linfeng
-- @Date:   2017-05-17 17:14:13
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-15 09:18:16

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local datasheet = require "skynet.datasheet"
local cjson = require "cjson"
local EntityImpl = {}

function EntityImpl:MakeRedisKey(row, key)
	return row[key]
end

function EntityImpl:MergeMysqlNumberString( cmd, value )
	local valueType = type(value)
	if valueType == "string" then
		return cmd .. "'%s'"
	elseif valueType == "number" then
		return cmd .. "%d"
	else
		assert(false, "invalid type(" .. valueType .. ") for msyql cmd merge")
	end
end

function EntityImpl:loadConfigMysqlImpl( tbname )
	local ret = {}
	local index = 0
	local index_limit = 1000
	local cmd = ""

	local configEntity = self:GetEntityCfg(TB_CONFIG, tbname)

	while true do
		cmd = string.format("select * from %s limit %d,%d",configEntity.name,index,index_limit)
		local sqlRet = MySqlExecute(cmd)
		if #sqlRet <= 0 then break end

		for _,row in pairs(sqlRet) do
			--json extract
			assert(table.size(row) == 2, "mysql table("..configEntity.name..") schema must be key-value")
			local decodeRow = cjson.decode(GetTableValueByIndex(row,2))

			--set to memory
			ret[tonumber(row[configEntity.key]) or row[configEntity.key]] = decodeRow
		end

		if #sqlRet < index_limit then break end

		index = index + index_limit
	end
	return ret
end

function EntityImpl:loadConfigMongoImpl( tbname )
	assert(false,"not impl loadConfigMongoImpl")
end

function EntityImpl:loadCommonMysqlImpl( tbname )
	local ret = {}
	local index = 0
	local index_limit = 1000
	local cmd = ""

	local commonEntity = self:GetEntityCfg(TB_COMMON, tbname)
	while true do
		cmd = string.format("select * from %s limit %d,%d",commonEntity.name,index,index_limit)
		local sqlRet = MySqlExecute(cmd)
		if #sqlRet <= 0 then break end

		for _,row in pairs(sqlRet) do
			--json extract
			assert(table.size(row) == 2, "mysql table("..commonEntity.name..") schema must be key-value")
			local decodeRow = cjson.decode(GetTableValueByIndex(row,2))

			--set to memory
			ret[tonumber(row[commonEntity.key])] = decodeRow
			if max_pk < pk then max_pk = pk end
		end

		if #sqlRet < index_limit then break end
		index = index + index_limit
	end
	return ret
end

function EntityImpl:loadCommonMongoImpl( tbname )
	assert(false,"not impl loadCommonMongoImpl")
end

function EntityImpl:loadCommonSingleMysqlImpl( tbname, indexvalue )
	local commonEntity = self:GetEntityCfg(TB_COMMON, tbname)
	local cmd = string.format(self:MergeMysqlNumberString("select * from %s where %s->'$.%s' = ",indexvalue),
																							commonEntity.name,
																							commonEntity.value,
																							commonEntity.indexkey,
																							indexvalue
							)

	local sqlRet = MySqlExecute(cmd)
	if #sqlRet <= 0 then return end
	sqlRet = sqlRet[1]
	
	--json extract
	assert(table.size(sqlRet) == 2, "mysql table("..commonEntity.name..") schema must be key-value")
	return cjson.decode(GetTableValueByIndex(sqlRet,2))
end

function EntityImpl:loadCommonSingleMongoImpl( tbname, indexvalue )
	assert(false,"not impl loadCommonSingleMongoImpl")
end

function EntityImpl:loadUserRedisImpl( tbname, uid )
	local cmd = string.format("hgetall %s:%d", tbname, uid)
	local ret = RedisExecute(cmd)
	if ret and not table.empty(ret) then
		--convert to k,v
		return ConvertIpairToKv(ret)
	end

	return nil --not user data in redis, or expried, must reload from db(mysql or mongo)
end

function EntityImpl:loadUserMysqlImpl( tbname, uid )
	local ret = {}
	setmetatable(ret, { __mode = "k" } ) --key weak table

	local cmd = ""
	local userEntity = self:GetEntityCfg(TB_USER, tbname)
	cmd = string.format(self:MergeMysqlNumberString("select * from %s where %s->'$.%s' = ",uid), 
																					userEntity.name, 
																					userEntity.value, 
																					userEntity.indexkey, 
																					uid
						)

	local sqlRet = MySqlExecute(cmd)
	if #sqlRet <= 0 then return end
	for _,row in pairs(sqlRet) do
		--json extract
		assert(table.size(row) == 2, "mysql table("..userEntity.name..") schema must be key-value")
		local decodeRow = cjson.decode(GetTableValueByIndex(row,2))
		local redisDecodeRow = TableUnpackToString(decodeRow, true)
		--set to redis
		local redisKey = self:MakeRedisKey(decodeRow,userEntity.indexkey)
		cmd = string.format("hmset %s:%s %s",userEntity.name,redisKey,redisDecodeRow)
		RedisExecute(cmd) --default to first redis instance
		--set to memory
		ret = decodeRow
	end

	return ret
end

function EntityImpl:loadUserMongoImpl( tbname, uid )
	assert(false,"not impl loadUserMongoImpl")
end

function EntityImpl:LoadConfig( tbname, dbNode )
	if dbNode then
		return RpcCall(dbNode, REMOTE_SERVICE, REMOTE_CALL, tbname, "Load" )
	else
		--从db获取config数据
		if G_DBTYPE == DBTYPE_MYSQL then
			return self:loadConfigMysqlImpl(tbname)
		elseif G_DBTYPE == DBTYPE_MONGO then
			return self:loadConfigMongoImpl(tbname)
		else
			assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
		end
	end
end

function EntityImpl:LoadCommon( tbname, dbNode, indexvalue )
	if dbNode then
		return RpcCall(dbNode, REMOTE_SERVICE, REMOTE_CALL, tbname, "Load", indexvalue )
	else
		--从db获取common数据
		if G_DBTYPE == DBTYPE_MYSQL then
			if indexvalue then
				return self:loadCommonSingleMysqlImpl(tbname, indexvalue)
			else
				return self:loadCommonMysqlImpl(tbname)
			end
		elseif G_DBTYPE == DBTYPE_MONGO then
			if indexvalue then
				return self:loadCommonSingleMongoImpl(tbname, indexvalue)
			else
				return self:loadCommonMongoImpl(tbname)
			end
		else
			assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
		end
	end
end

function EntityImpl:LoadUser( tbname, uid, dbNode )
	if dbNode then
		return RpcCall(dbNode, REMOTE_SERVICE, REMOTE_CALL, tbname, "Load", uid)
	else
		--尝试从redis获取user数据
		local ret = self:loadUserRedisImpl(tbname, uid)
		if not ret then
			--从db获取user数据
			if G_DBTYPE == DBTYPE_MYSQL then
				return self:loadUserMysqlImpl(tbname, uid)
			elseif G_DBTYPE == DBTYPE_MONGO then
				return self:loadUserMongoImpl(tbname, uid)
			else
				assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
			end
		end

		return ret
	end
end

function EntityImpl:UpdateCommonMysql( tbname, dataIndex )
	--update 20 record per query
	assert(type(dataIndex) == "table")
	local obj = self:GetEntityCfg(TB_COMMON, tbname)
	
	local sql = string.format(self:MergeMysqlNumberString("update %s set %s = '%s' where %s->'$.%s' = ",dataIndex[obj.indexkey]),
																									obj.name, 
																									obj.value, 
																									cjson.encode(dataIndex),
																									obj.value, 
																									obj.indexkey,
																									dataIndex[obj.indexkey]
							)
		
	--update obj.name by dataIndex's index to mysql
	local ret = MySqlExecute(sql) 
	--check ret
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "UpdateCommon err:%s, info:%s",sql, ret.badresult)
	end

	return ret
end

function EntityImpl:UpdateCommonMongo( tbname, dataIndex )
	assert(false,"not impl UpdateCommonMongo")
end

function EntityImpl:UpdateUserMysql( tbname, dataIndex )
	assert(type(dataIndex) == "table")
	local obj = self:GetEntityCfg(TB_USER, tbname)
	local uid = assert(dataIndex[obj.indexkey])
	--mysql
	local sqlCmd = string.format(self:MergeMysqlNumberString("update %s set %s = '%s' where %s->'$.%s' = ",uid),
																									obj.name, 
																									obj.value, 
																									cjson.encode(dataIndex),
																									obj.value,
																									obj.indexkey,
																									uid
								)
	

	--redis
	local redisCmds = {}
	local redisCmd
	table.insert(redisCmds, string.format("del %s:%d",obj.name, uid))
	redisCmd = string.format("hmset %s:%d ", obj.name, uid)
	redisCmd = redisCmd .. table.kv(dataIndex, " ")
	table.insert(redisCmds,redisCmd)
	
	--update to redis first with redis pipeline
	RedisExecute(redisCmds, uid, true)

	--update obj.name by dataIndex's index to mysql
	local ret = MySqlExecute(sqlCmd, uid) 
	--check ret
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "UpdateUser err:%s, info:%s",sqlCmd, ret.badresult)
		return false
	end

	return true
end

function EntityImpl:UpdateUserMongo( tbname, dataIndex )
	-- body
end

function EntityImpl:UpdateConfig( ... )
	assert(false, "UpdateConfig is forbid")
end

function EntityImpl:UpdateCommon( tbname, dataIndex )
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:UpdateCommonMysql(tbname, dataIndex)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:UpdateCommonMongo(tbname, dataIndex)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:UpdateUser( tbname, dataIndex )
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:UpdateUserMysql(tbname, dataIndex)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:UpdateUserMongo(tbname, dataIndex)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:DelCommonMysql( tbname, dataKeys)
	assert(type(dataKeys) == "table")
	local obj = assert(self:GetEntityCfg(TB_COMMON, tbname))
	local key = dataKeys[obj.key]
	local sqlCmd = string.format(self:MergeMysqlNumberString("delete from %s where %s = ",key),
																					obj.name,
																					obj.key,
																					key						
	)

	--del obj.name by dataKeys's index to mysql
	local ret = MySqlExecute(sqlCmd, uid) 
	--check ret
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "DelCommon err:%s, info:%s",sqlCmd, badresult)
	end

end

function EntityImpl:DelCommonMongo( tbname, dataKeys)
	assert(false, "not impl DelCommonMongo")
end

function EntityImpl:DelUserMysql( tbname, dataKeys )
	assert(type(dataKeys) == "table")
	local obj = assert(self:GetEntityCfg(TB_USER, tbname))

	local uid = dataKeys[obj.indexkey]
	local sqlCmd = string.format(self:MergeMysqlNumberString("delete from %s where %s->'$.%s' = ",uid),
																							obj.name,
																							obj.value,
																							obj.indexkey,
																							uid						
	)

	--del obj.name by dataKeys's index to mysql
	local ret = MySqlExecute(sqlCmd, uid) 
	--check ret
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "DelUser err:%s, info:%s",sqlCmd, ret.badresult)
	else
		--del redis user info
		local redisCmd = string.format("del %s:%d", obj.name, uid)
		RedisExecute(redisCmd, uid)
	end

	
end

function EntityImpl:DelUserMongo( tbname, dataKeys )
	assert(false, "not impl DelUserMongo")
end

function EntityImpl:DelConfig( tbname, dataKeys )
	assert(false, "DelConfig is forbid")
end

function EntityImpl:DelCommon( tbname, dataKeys )
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:DelCommonMysql(tbname, dataKeys)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:DelCommonMongo(tbname, dataKeys)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:DelUser( tbname, dataKeys )
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:DelUserMysql(tbname, dataKeys)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:DelUserMongo(tbname, dataKeys)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:AddConfig( ... )
	assert(false, "AddConfig is forbid")
end

function EntityImpl:AddCommon( tbname, dataRaw )
	assert(type(dataRaw) == "table")
	local obj = assert(self:GetEntityCfg(TB_COMMON,tbname))
	local key = dataRaw[obj.key]
	dataRaw[obj.key] = nil
	local sqlCmd = string.format("insert into %s values(%d,'%s')",obj.name, key, cjson.encode(dataRaw))

	local ret = MySqlExecute(sqlCmd, key)
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "AddCommon err:%s,msg:%s",sqlCmd, ret.badresult)
		return false
	end

	return true
end

function EntityImpl:AddUser( tbname, id, dataRaw )
	assert(type(dataRaw) == "table")
	local obj = assert(self:GetEntityCfg(TB_USER,tbname))
	local indexkey = dataRaw[obj.indexkey]
	local sqlCmd = string.format("insert into %s values(%d,'%s')",obj.name, id, cjson.encode(dataRaw))
	local ret = MySqlExecute(sqlCmd, indexkey)
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "AddUser Error:%s,msg:%s",sqlCmd, ret.badresult)
		return false
	end

	--add to redis
	local redisCmd = string.format("hmset %s:%d ", obj.name, indexkey)
	redisCmd = redisCmd .. table.kv(dataRaw, " ")
	RedisExecute(redisCmd, indexkey)

	return true
end

function EntityImpl:SetEntityCfg( config, common, user )
	local tb = {}
	tb[TB_CONFIG] 	= 	config
	tb[TB_COMMON] 	= 	common
	tb[TB_USER] 	= 	user

	SM.sharemgr.req.NewDataSheet(SHARE_ENTITY_CFG, tb)
	self:RecordMaxIdToRedis()
end

function EntityImpl:GetEntityCfg( tbtype, tbname )
	local tb = datasheet.query(SHARE_ENTITY_CFG)
	if tbname and tb then
		for _,v in pairs(tb[tbtype]) do
			if v.name == tbname then
				return v
			end
		end
	else
		return tb[tbtype]
	end
end

function EntityImpl:MaxIdToRedis( name, key )
	local cmd = string.format("select max(%s) as %s from %s",key,key,name)
	local ret = MySqlExecute(cmd)
	assert(ret.badresult == nil, "execute sql fail:"..cmd..",err:"..(ret.err or ""))
	cmd = string.format("set %s:%s %d",name,key,tonumber(ret[1][key]) or 0)
	RedisExecute(cmd)
end

function EntityImpl:RecordMaxIdToRedis()
	local tb = datasheet.query(SHARE_ENTITY_CFG)
	for _,cfg in pairs(tb) do
		for _,tbcfg in pairs(cfg) do
			self:MaxIdToRedis(tbcfg.name, tbcfg.key)
		end
	end
end

return EntityImpl