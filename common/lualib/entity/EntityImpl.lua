-- @Author: linfeng
-- @Date:   2017-05-17 17:14:13
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-27 18:04:49

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local sharedata = require "sharedata"
local cjson = require "cjson"

local EntityImpl = {}
local dbname = skynet.getenv("mysqldb")


function EntityImpl:MakeRedisKey(row, key)
	return row[key]
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
		end

		index = index + index_limit
	end
	return ret
end

function EntityImpl:loadCommonMongoImpl( tbname )
	assert(false,"not impl loadCommonMongoImpl")
end

function EntityImpl:loadUserRedisImpl( tbname, uid )
	local cmd = string.format("hgetall %s:%d", tbname, uid)
	local ret = RedisExecute(cmd)

	if ret and not table.empty(ret) then
		return ret --ret is a table
	end

	return nil --not user data in redis, or expried, must reload from db(mysql or mongo)
end

function EntityImpl:loadUserMysqlImpl( tbname, uid )
	local ret = {}
	setmetatable(ret, { __mode = "k" } ) --key weak table

	local cmd = ""
	local userEntity = self:GetEntityCfg(TB_USER, tbname)
	cmd = string.format("select * from %s where %s->'$.%s' = %d", 
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
		local redisKey = self:MakeRedisKey(decodeRow,userEntity.key)
		cmd = string.format("hmset %s:%s %s",userEntity.tbname,redisKey,redisDecodeRow)
		RedisExecute(cmd) --default to first redis instance

		--set to memory
		ret = decodeRow
	end

	return ret
end

function EntityImpl:loadUserMongoImpl( tbname, uid )
	assert(false,"not impl loadUserMongoImpl")
end

function EntityImpl:LoadConfig( tbname )
	--从db获取config数据
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:loadConfigMysqlImpl(tbname)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:loadConfigMongoImpl(tbname)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:LoadCommon( tbname )
	--从db获取common数据
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:loadCommonMysqlImpl(tbname)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:loadCommonMongoImpl(tbname)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function EntityImpl:LoadUser( tbname, uid, dbNode )
	if dbNode then
		return RpcCall(dbNode, REMOTE_DB_SERVICE, REMOTE_CALL, tbname, "Load", uid)
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
	end
end

function EntityImpl:UpdateCommonMysql( tbname, dataIndex )
	--update 20 record per query
	assert(type(dataIndex) == "table")
	local obj = self:GetEntityCfg(TB_COMMON, tbname)
	local i = 1
	while true do
		local sql = {}
		for index,data in pairs(dataIndex) do
			table.insert(sql,string.format("update %s set %s = %s where %d = %d;",
																				obj.tbname, 
																				obj.value, 
																				cjson.encode(data),
																				obj.key,
																				index)
			)
			i = i + 1
			if i % 20 == 0 then break end
		end

		--update obj.tbname by dataIndex's index to mysql
		local ret = MySqlExecute(table.concat(sql)) 
		--check ret,to do
		local checkRet,errIndex = CheckMysqlResult(ret)
		if not checkRet then
			for index,msg in pairs(errIndex) do
				LOG_SYS(E_LOG_DB, "UpdateCommon err:%s, info:%s",sql[index], msg);
			end
		end

		if i >= table.size(dataIndex) then break end
	end 
end

function EntityImpl:UpdateCommonMongo( tbname, dataIndex )
	assert(false,"not impl UpdateCommonMongo")
end

function EntityImpl:UpdateUserMysql( tbname, dataIndex )
	assert(type(dataIndex) == "table")
	local obj = self:GetEntityCfg(TB_USER, tbname)
	local i = 1
	while true do
		local sqlCmds = {}
		local redisCmds = {}
		local redisCmd
		for uid,data in pairs(dataIndex) do
			--mysql
			table.insert(sqlCmds,string.format("update %s set %s = %s where %s->'$.%s' = %d;",
																				obj.tbname, 
																				obj.value, 
																				cjson.encode(data),
																				obj.value,
																				obj.indexkey,
																				uid)
			)

			--redis
			table.insert(redisCmds, string.format("del %s:%d",obj.tbname, uid))
			redisCmd = string.format("hmset %s:%d ", obj.tbname, uid)
			redisCmd = redisCmd .. table.concat(data, " ")
			table.insert(redisCmds, redisCmd)

			--update to redis first with redis pipeline
			RedisExecute(redisCmds, uid, true)

			--update obj.tbname by dataIndex's index to mysql
			local ret = MySqlExecute(table.concat(sqlCmds), uid) 
			--check ret
			local checkRet,errIndex = CheckMysqlResult(ret)
			if not checkRet then
				for index,msg in pairs(errIndex) do
					LOG_SYS(E_LOG_DB, "UpdateCommon err:%s, info:%s",sqlCmds[index], msg);
				end
			end

			i = i + 1
			if i % 20 == 0 then break end --update 20 record per query
		end

		if i >= table.size(dataIndex) then break end
	end 
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
	local sqlCmd

	for _,key in pairs(dataKeys) do
		sqlCmd = string.format("delete from %s where %s = %d;",
																			obj.tbname,
																			obj.key,
																			key						
		)

		--del obj.tbname by dataKeys's index to mysql
		local ret = MySqlExecute(sqlCmds, uid) 
		--check ret
		local checkRet,errIndex = CheckMysqlResult(ret)
		if not checkRet then
			for index,msg in pairs(errIndex) do
				LOG_SYS(E_LOG_DB, "DelCommon err:%s, info:%s",sqlCmds[index], msg);
			end
		end
	end
end

function EntityImpl:DelCommonMongo( tbname, dataKeys)
	assert(false, "not impl DelCommonMongo")
end

function EntityImpl:DelUserMysql( tbname, dataKeys )
	assert(type(dataKeys) == "table")
	local obj = assert(self:GetEntityCfg(TB_USER, tbname))

	local sqlCmd
	local redisCmd
	for _,uid in pairs(dataKeys) do
		sqlCmd = string.format("delete from %s where %s->'$.%s' = %d;",
																			obj.tbname,
																			obj.value,
																			obj.indexkey,
																			uid						
		)

		--del obj.tbname by dataKeys's index to mysql
		local ret = MySqlExecute(sqlCmds, uid) 
		--check ret
		local checkRet,errIndex = CheckMysqlResult(ret)
		if not checkRet then
			for index,msg in pairs(errIndex) do
				LOG_SYS(E_LOG_DB, "UpdateCommon err:%s, info:%s",sqlCmds[index], msg);
			end
		end

		--del redis user info
		redisCmd = string.format("del %s:%d", obj.tbname, uid)
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
	local sqlCmd = string.format("insert into %s values(%d,%s)",obj.tbname, key, cjson.encode(dataRaw))

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
	local sqlCmd = string.format("insert into %s values(%d,%s)",obj.tbname, id, cjson.encode(dataRaw))

	local ret = MySqlExecute(sqlCmd, indexkey)
	if ret.badresult then
		LOG_SYS(E_LOG_DB, "AddUser Error:%s,msg:%s",sqlCmd, ret.badresult)
		return false
	end

	--add to redis
	local redisCmd = string.format("hmset %s:%d ", obj.tbname, indexkey)
	redisCmd = redisCmd .. table.concat(dataRaw, " ")
	RedisExecute(redisCmd, indexkey)

	return true
end

function EntityImpl:SetEntityCfg( config, common, user )
	local tb = {}
	tb[TB_CONFIG] 	= 	config
	tb[TB_COMMON] 	= 	common
	tb[TB_USER] 	= 	user

	sharedata.new(SHARE_ENTITY_CFG, tb)
end

function EntityImpl:GetEntityCfg( tbtype, tbname )
	local tb = sharedata.query(SHARE_ENTITY_CFG)
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

return EntityImpl