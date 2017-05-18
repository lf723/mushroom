-- @Author: linfeng
-- @Date:   2017-05-17 17:14:13
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-18 14:56:49

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local sharedata = require "sharedata"
local cjson = require "cjson"

local LoadEntity = {}
local dbname = skynet.getenv("mysqldatabase")

local function LoadEntity:GetPrimaryKey(tbname)

	local sql = string.format([[select k.column_name 
				from information_schema.table_constraints t 
				join information_schema.key_column_usage k 
				using (constraint_name,table_schema,table_name) 
				where t.constraint_type = 'PRIMARY KEY' 
				and t.table_schema= '%s'
				and t.table_name = '%s']],dbname,tbname)
	
	local t = MysqlExecute(sql)

	if table.size(t) <= 0 then
		LOG_ERROR("GetPrimaryKey tbname:%s,not exist,result:%s",tbname,tostring(t))
		return nil
	end

	return t[1]["column_name"]
end

local function LoadEntity:MakeRedisKey(row, key)
	return row[key]
end

local function LoadEntity:loadConfigMysqlImpl( tbname )
	local ret
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
			assert(#row == 2, "mysql table("..configEntity.name..") schema must be key-value")
			local decodeRow = cjson.decode(row[2])
			local redisDecodeRow = TableUnpackToString(decodeRow)

			--set to redis
			local redisKey = self:MakeRedisKey(decodeRow,configEntity.key)
			cmd = string.format("hmset %s:%s %s",tbname,redisKey,redisDecodeRow)
			RedisExecute(cmd) --default to first redis instance

			--set to memory
			ret[tonumber(row[1]) or row[1]] = decodeRow
		end

		index = index + index_limit
	end
	return ret
end

local function LoadEntity:loadConfigMongoImpl( tbname )
	-- body
end

local function LoadEntity:loadCommonMysqlImpl( tbname )
	local ret
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
			assert(#row == 2, "mysql table("..commonEntity.name..") schema must be key-value")
			local decodeRow = cjson.decode(row[2])
			local redisDecodeRow = TableUnpackToString(decodeRow)

			--set to redis
			local redisKey = self:MakeRedisKey(decodeRow,commonEntity.key)
			cmd = string.format("hmset %s:%s %s",tbname,redisKey,redisDecodeRow)
			RedisExecute(cmd) --default to first redis instance

			--set to memory
			ret[tonumber(row[1]) or row[1]] = decodeRow
		end

		index = index + index_limit
	end
	return ret
end

local function LoadEntity:loadCommonMongoImpl( tbname )
	-- body
end

local function LoadEntity:loadUserMysqlImpl( tbname, uid )
	local ret
	local cmd = ""

	local userEntity = self:GetEntityCfg(TB_USER, tbname)

	cmd = string.format("select * from %s where %s = %d", userEntity.name, userEntity.key, uid)
	local sqlRet = MySqlExecute(cmd)
	if #sqlRet <= 0 then return end

	for _,row in pairs(sqlRet) do
		--json extract
		assert(#row == 2, "mysql table("..userEntity.name..") schema must be key-value")
		local decodeRow = cjson.decode(row[2])
		local redisDecodeRow = TableUnpackToString(decodeRow)

		--set to redis
		local redisKey = self:MakeRedisKey(decodeRow,userEntity.key)
		cmd = string.format("hmset %s:%s %s",tbname,redisKey,redisDecodeRow)
		RedisExecute(cmd) --default to first redis instance

		--set to memory
		ret[tonumber(row[1]) or row[1]] = decodeRow
	end
	
	return ret
end

local function LoadEntity:loadUserMongoImpl( tbname, uid )
	-- body
end

function LoadEntity:LoadConfig( tbname )
	--从db获取config数据
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:loadConfigMysqlImpl(tbname)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:loadConfigMongoImpl(tbname)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function LoadEntity:LoadCommon( tbname )
	--从db获取common数据
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:loadCommonMysqlImpl(tbname)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:loadCommonMongoImpl(tbname)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function LoadEntity:LoadUser( tbname, key )
	--从db获取user数据
	if G_DBTYPE == DBTYPE_MYSQL then
		return self:loadUserMysqlImpl(tbname)
	elseif G_DBTYPE == DBTYPE_MONGO then
		return self:loadUserMongoImpl(tbname)
	else
		assert(false,"invalid dbtype:" .. G_DBTYPE .. ",only mysql or mongo")
	end
end

function LoadEntity:SetEntityCfg( config, user, common )
	local tb = {}
	tb[TB_CONFIG] 	= 	config
	tb[TB_USER] 	= 	config
	tb[TB_COMMON] 	= 	config

	if not sharedata.query(SHARE_ENTITY_CFG) then
		sharedata.new(SHARE_ENTITY_CFG, tb)
	else
		sharedata.update(SHARE_ENTITY_CFG, tb)
	end
end

function LoadEntity:GetEntityCfg( tbtype, tbname )
	local tb = sharedata.query(SHARE_ENTITY_CFG)

	if tbname and tb then
		for _,v in pairs(tb) do
			if v.name == tbname then
				return v
			end
		end
	else
		return tb[tbtype]
	end
end