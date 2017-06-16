local msgserver = require "gamegate"
local crypt = require "crypt"
local skynet = require "skynet"
local cluster = require "cluster"
local snax = require "snax"

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
		table.insert(agents, assert(snax.newservice("agent")))
	end
end

-- login server disallow multi login, so login_handler never be reentry
-- call by login server
function server.login_handler(uid, secret, lserver, dserver, newUser)
	if users[uid] then
		--kick
		server.kick_handler( uid, users[uid].subid)
	end

	internal_id = internal_id + 1
	local subid = internal_id	-- don't use internal_id directly
	local username = msgserver.username(uid, subid, servername)

	local agent = agents[uid % maxAgent + 1]
	local u = {
		username = username,
		agent = agent,
		uid = uid,
		subid = subid,
		lserver = lserver,
		dserver = dserver,
	}

	-- trash subid (no used)
	agent.req.login( skynet.self(), uid, subid, secret, u.dserver, newUser)

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
		pcall(u.agent.req.logout, skynet.self(), u.uid)
	end
end

-- call by self (when recv first auth)
function server.auth_handler( username, fd )
	local uid = msgserver.userid(username)
	local u = users[tonumber(uid)]
	if u then
		u.agent.req.auth( u.uid, fd )
	end
end

-- call by self (when socket disconnect)
function server.disconnect_handler(username)
	local u = username_map[username]
	if u then
		u.agent.req.afk( skynet.self(),u.uid )
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