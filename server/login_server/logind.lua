local login = require "logingate"
local crypt = require "skynet.crypt"
local skynet = require "skynet"
local cluster = require "skynet.cluster"

local server = {
	host = "0.0.0.0",
	port = tonumber(skynet.getenv("port")) or 8001,
	multilogin = false,	-- disallow multilogin
	name = "logind",
	instance = 20,
}

local selfNodeName = skynet.getenv("clusternode") .. skynet.getenv("serverid")

local server_list = {}
local user_online = {}
local user_login = {}

local function DistributeServer( uid )
	local f = io.open(skynet.getenv("cluster"), "r")
	if not f then
		assert(false, "DistributeServer Not Found cluster file")
	end

	local _centerserver = GetClusterNodeByName("center", true)
	assert(_centerserver)
	local dbserver
	for _,node in pairs(_centerserver) do
		dbserver = RpcCall( node, "route", "GetUserSvr", uid)
		if dbserver then break end
	end
	
	local newUser =false
	--未找到,新玩家
	if not dbserver then
		--后期需要配合运营,新玩家导入到指定服
		--to do
		newUser = true
		dbClusterNodes = GetClusterNodeByName("db", true)
		dbserver = dbClusterNodes[ uid % #dbClusterNodes + 1]
	end

	local gameClusterNodes = GetClusterNodeByName("game", true)
	local id = uid % #gameClusterNodes + 1
	local gameserver = gameClusterNodes[id]
	return dbserver, gameserver, newUser
end

local function CheckIggId( uid )
	--check to web,to do
	return true
end

function server.auth_handler(token)
	local uid = assert(tonumber(token))
	--check uid
	if not CheckIggId(uid) then
		assert(false,"invalid client token")
	end

	--distribute world server for uid
	local dbserver, gameserver, newUser = DistributeServer(uid)
	return string.format("%s#%s#%s",dbserver, gameserver, tostring(newUser)), uid
end

function server.login_handler(dgserver, uid, secret)
	LOG_INFO(string.format("%s@%s is login, secret is %s", uid, dgserver, crypt.hexencode(secret)))
	local dbserver,gameserver,newUser = dgserver:match("([^#]*)#([^#]*)#(.*)")
	if not GetClusterNodeByName(gameserver) then
		assert(false, "Unknown server")
	end

	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	if last then
		if pcall(cluster.proxy,last.gameserver, "gamed") then
			pcall(cluster.call,last.gameserver, "gamed", "kick", uid, last.subid)
		end
		user_online[uid] = nil
	end

	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end

	local ok,subid,connectIp,connectPort = pcall(cluster.call, gameserver, "gamed", "login", uid, secret, selfNodeName, dbserver, newUser )
	if ok then
		user_online[uid] = { subid = subid , gameserver = gameserver, dbserver = dbserver }
		return string.format("%s@%s#%s %s@%s", 
			crypt.base64encode(uid), crypt.base64encode(gameserver), crypt.base64encode(tostring(subid)),
			crypt.base64encode(connectIp), crypt.base64encode(tostring(connectPort)))
	else
		LOG_ERROR("notify %s uid %d login error->%s",gameserver, uid, subid)
		error("notify game server error")
	end
end

local CMD = {}

function CMD.logout( uid )
	local u = user_online[uid]
	if u then
		LOG_INFO(string.format("%s@%s is logout", uid, u.gameserver))
		user_online[uid] = nil
	end
end

function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)