-- @Author: linfeng
-- @Date:   2017-05-31 10:48:03
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-21 09:30:27


local svr =  "../../../common/lualib/?.lua;".."./?.lua;"
package.path = "../../../3rd/skynet/lualib/?.lua;../../../3rd/skynet/service/?.lua;"..svr
package.cpath = "../../../3rd/skynet/luaclib/?.so;../../../common/luaclib/?.so"

local log = require "log.core"
local socket = require "clientsocket"
local crypt = require "crypt"
local string = string
local table = table
local math = math
require "luaext"

local loginip = "127.0.0.1"
local loginport = 10000
local loginState = false


local rawprint = print
local print = function ( ... )
	rawprint(...)
end


--#######################################################################################################

local function sendpack(fd,msg,cmd)
	if not cmd then
		msg = msg
		return socket.send(fd, msg)
	else
		local size = #msg
		local package
		if not cmd then
			session = session + 1
			size = size + 4
			package = string.char(size >> 8) ..
						string.char(size & 0xff)..
						msg..string.char(session >> 24)..string.char(session >> 16)..
						string.char(session >> 8)..string.char(session & 0xff)
		else
			package = string.char(size >> 8) ..
						string.char(size & 0xff)..
						msg
		end

		return socket.send(fd, package)
	end
end

local function unpack( data )

	data = data:sub(1,-6)
	data = crypt.base64decode(crypt.desdecode(clisecret,data))
	data = uncompress(data)

	local pb = protobuf.decode("gate.GateMessage",data)
	if pb.content then
		local ret
		for _,v in pairs(pb.content) do
			if v.error_message.code ~= 0 then
				print("error:"..v.error_message.code.."-->"..v.error_message.description)
			else
				if v.proto_name and v.network_message then
					ret = protobuf.decode(v.proto_name,v.network_message)
					print(ret)
				end
			end
		end
		return ret
	end
end

local last = ""

local function recvpack(fd)
	if loginState == false then
		local ret
		while ret == nil do
			ret = socket.recv(fd)
		end
		return string.trim(ret,'\n')
	else
		local ret
		while ret == nil do
			ret = socket.recv(fd)
		end
		if #last > 0 then
			ret = last..ret
		end

		if #ret > 2 then
			local len = (string.byte(ret,2) & 0xff) + ((string.byte(ret,1) & 0xff) << 8) + 2
			while #ret < len do
				local tmp 
				while tmp == nil do
					tmp = socket.recv(fd)
				end
				ret = ret..tmp
			end

			local pack = string.sub(ret,3,len)
			if #ret > len then
				last = last..string.sub(ret,len+1,#ret)
			end
			print("Response size:"..#pack)
			return pack
		else
			last = last..ret
			recvpack(fd)
		end
	end
end

local function make_randomkey( )
	clikey = crypt.randomkey()
	return crypt.base64encode(crypt.dhexchange(clikey))
end

local function make_crypt_token( token )
	return crypt.base64encode(crypt.desencode(clisecret,token))
end

local index = 0
local function make_auth( username )
	index = index + 1
	local handshake = string.format("%s:%d",username,index)
	local encrypt = crypt.hmac64(crypt.hashkey(handshake),clisecret)
	local hmac = crypt.base64encode(encrypt)
	return string.format("%s:%s",handshake,hmac)
end

--#########################################################################################################
local CMD = {}

function CMD.login( token )
	assert(token)
	local lfd = assert(socket.connect(loginip,loginport))
	local ret = recvpack(lfd)
	local challenge = crypt.base64decode(ret)
	print("recv challenge code:"..challenge)

	sendpack(lfd,make_randomkey() .. "\n")
	ret = recvpack(lfd)

	local svrkey = crypt.base64decode(ret)
	print("recv server key:"..svrkey)

	clisecret = crypt.dhsecret(svrkey,clikey)
	local encrypt = crypt.hmac64(challenge,clisecret)
	sendpack(lfd,crypt.base64encode(encrypt) .. "\n")

	sendpack(lfd,make_crypt_token(token) .. "\n")
	ret = recvpack(lfd)
	print("recv challenge result:"..ret)
	if not ret:find("200") then
		print("challenge fail:"..ret)
		socket.close(lfd)
		return
	end

	local username = crypt.base64decode(ret:sub(5,#ret))
	-- base64(uid)@base64(server)#base64(subid) base64(connectip)@base64(connectport)
	local uid, servername, subid, connectip, connectport = username:match "([^@]*)@([^#]*)#(.*) ([^@]*)@(.*)"
	username = string.split(username," ")[1]
	connectip = crypt.base64decode(connectip)
	connectport = crypt.base64decode(connectport)
	print(string.format("login ok,username %s,ip=%s, port=%s", 
		username,connectip , connectport))

	socket.close(lfd)
	return username,connectip,connectport
end

function CMD.auth( token, close)
	assert(token)
	local login_before = os.time()
	local username,connectip,connectport = CMD.login(token)
	local login_end = os.time()
	if username == nil then
		return
	end
	G_USERNAME = username
	local auth_before = os.time()
	local gfd = assert(socket.connect(connectip, tonumber(connectport)))
	sendpack(gfd,make_auth(username),true)
	local pack = recvpack(gfd)
	local ret  = false
	if pack:find("200") then
		ret = true
		print("auth ok")
	else
		print("auth fail")
	end
	local auth_end = os.time()

	if close == nil then
		socket.close(gfd)
	end
	return gfd,ret, connectip, tonumber(connectport)
end

function CMD.reauth( token )
	assert(token)
	local _,ret,connectip,connectport = CMD.auth( token, true)
	if not ret then
		print("first auth error")
		return
	end
	print("reauth after 10s...")
	socket.usleep(1000000 * 10)

	local gfd = assert(socket.connect(connectip, tonumber(connectport)))
	sendpack(gfd,make_auth(G_USERNAME),true)
	local pack = recvpack(gfd)
	local ret  = false
	if pack:find("200") then
		ret = true
		print("auth ok")
	else
		print("auth fail:"..pack)
	end

	socket.close(gfd)
end

function CMD.repeatauth( token )
	print(token)
	assert(token)
	local uid = tonumber(token) * 1000000
	for i=1,100000 do
		uid = uid + 1
		CMD.auth(uid)
	end
end

function CMD.help(  )
	local info = 
[[
"Usage":lua client.lua cmd [args] ...
	help 		display this help
	login 		token
	auth 		token
	reauth 		token
	repeatauth 	token
]]
	print(info)
end

local function Run( cmd,... )
	if cmd == nil or cmd == "" then
		cmd = "help"
	end
	local f = assert(CMD[cmd],cmd)
	f(...)
end

local args = {...}
local t = string.split(table.concat(args," ")," ")

Run(table.unpack(t))
