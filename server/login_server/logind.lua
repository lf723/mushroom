local login = require "logingate"
local crypt = require "crypt"
local skynet = require "skynet"
local cluster = require "cluster"

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

local function DistributeServer( iggid )
	local f = io.open(skynet.getenv("cluster"), "r")
	if not f then
		assert(false, "DistributeServer Not Found cluster file")
	end

	local dbClusterNodes = GetClusterNodeByName("db", true)
	local ret
	for _,v in pairs(dbClusterNodes) do
		ret = RpcCall(v, REMOTE_SERVICE, REMOTE_CALL, "user", "Get", iggid)
		if ret then ret = v break end
		ret = nil
	end
	
	local worldClusterNodes = GetClusterNodeByName("world", true)
	
	--未找到,新玩家
	if not ret then
		--后期需要配合运营,新玩家导入到指定服
		--to do
		local worldId = iggid % #worldClusterNodes + 1
		ret = worldClusterNodes[worldId]
	end

	return ret
end

local function CheckIggId( iggid )
	--check to web,to do
	return true
end

function server.auth_handler(token)
	-- the token is base64(user)@base64(server):base64(password)
	--local user, server, password = token:match("([^@]+)@([^:]+):(.+)")
	--user = crypt.base64decode(user)
	--server = crypt.base64decode(server)
	--password = crypt.base64decode(password)
	--assert(password == "password", "Invalid password")

	local iggid = assert(tonumber(token))
	--check iggid
	if not CheckIggId(iggid) then
		assert(false,"invalid client token")
	end

	--distribute world server for iggid
	local authserver = DistributeServer(iggid)

	return authserver, iggid
end

function server.login_handler(server, uid, secret)
	LOG_INFO(string.format("%s@%s is login, secret is %s", uid, server, crypt.hexencode(secret)))
	if not GetClusterNodeByName(server) then
		assert(false, "Unknown server")
	end

	-- only one can login, because disallow multilogin
	local last = user_online[uid]
	if last then
		pcall(cluster.call,last.server, "gated", "kick", uid, last.subid)
	end

	if user_online[uid] then
		error(string.format("user %s is already online", uid))
	end

	local ok,subid,connectIp,connectPort = pcall(cluster.call, server, "gated", "login", uid, secret, selfNodeName )
	if ok then
		user_online[uid] = { subid = subid , server = server}
		return string.format("%s@%s#%s %s@%s", 
			crypt.base64encode(uid), crypt.base64encode(server), crypt.base64encode(tostring(subid)),
			crypt.base64encode(connectIp), crypt.base64encode(tostring(connectPort)))
	else
		LOG_ERROR("notify %s uid %d login error->%s",server, uid, subid)
		error("notify world server error")
	end
end

local CMD = {}

function CMD.logout( uid )
	local u = user_online[uid]
	if u then
		LOG_INFO(string.format("%s@%s is logout", uid, u.server))
		user_online[uid] = nil
	end
end

function server.command_handler(command, ...)
	local f = assert(CMD[command])
	return f(...)
end

login(server)