local msgserver = require "msggate"
local crypt = require "crypt"
local skynet = require "skynet"
local cluster = require "cluster"
--local loginservice = tonumber(...)

local server = {}
local users = {}
local username_map = {}
local internal_id = 0
local agents = {}
local maxAgent

local connectIp = skynet.getenv("connectip")
local connectPort = skynet.getenv("port")

local function allocAgent( ... )
	maxAgent = assert(tonumber(skynet.getenv("maxclient"))) // 100 --100 client per agent, auto branche
	for i=1,maxAgent do
		table.insert(agents, assert(skynet.newservice("agent")))
	end
end

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
function server.login_handler(uid, secret, lserver)

	if users[uid] then
		error(string.format("%s is already login", uid))
	end

	internal_id = internal_id + 1
	local subid = internal_id	-- don't use internal_id directly
	local username = msgserver.username(uid, subid, servername)

	local agent = agents[uid % maxAgent]
	local u = {
		username = username,
		agent = agent,
		uid = uid,
		subid = subid,
		lserver = lserver,
	}

	-- trash subid (no used)
	skynet.call(agent, "lua", "login", uid, subid, secret)

	users[uid] = u
	username_map[username] = u

	msgserver.login(username, secret)

	-- you should return unique subid
	return subid, connectIp, connectPort
end

-- call by agent
function server.logout_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		msgserver.logout(u.username)
		users[uid] = nil
		username_map[u.username] = nil
		pcall(cluster.call, u.lserver, ".logind", "logout", uid)
	end
end

-- call by login server
function server.kick_handler(uid, subid)
	local u = users[uid]
	if u then
		local username = msgserver.username(uid, subid, servername)
		assert(u.username == username)
		-- NOTICE: logout may call skynet.exit, so you should use pcall.
		pcall(skynet.call, u.agent, "lua", "logout", u.uid)
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(username)
	local u = username_map[username]
	if u then
		skynet.call(u.agent, "lua", "afk")
	end
end

-- call by self (when recv a request from client)
function server.request_handler(username, msg)
	local u = username_map[username]
	return skynet.tostring(skynet.rawcall(u.agent, "client", msg, u.uid))
end

-- call by self (when gate open)
function server.register_handler(name)
	servername = name
	allocAgent()
end

skynet.register(SERVICE_NAME)

msgserver.start(server)