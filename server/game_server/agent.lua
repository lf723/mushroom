-- @Author: linfeng
-- @Date:   2017-02-07 16:09:00
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-15 09:18:19

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local string = string
local table = table
local math = math
local queue = require "skynet.queue"
local CriticalSection
local timer = require "timer"
local datasheet = require "skynet.datasheet"

local protocrypt
local userevent = require "logic.lualib.userevent"

local AgentStates = {}

local function GetProtocolCmd( name )
	local protocolEnum = assert(datasheet.query(SHARE_PROTOCOL_ENUM))
	return assert(protocolEnum[name])
end

-- brief : 合并推送消息,并清空队列
-- param : resp,推送消息索引;uid,合并的消息的uid
-- return : resp
local function MegerPushMsg( resp, uid )
	for _,v in pairs(AgentStates[uid].pushlist) do
		v.cmd = GetProtocolCmd(v.name)
		table.insert( resp.content, v )
	end
	return resp
end

-- brief : 插入pushmsg到指定的uid队列
-- param : pushlist,需要推送的消息, pushlist = { name = xxx, msg = xxx }
--return : nil
local function SetPushMsg( pushmsg, uid )
	if AgentStates[uid].pushlist == nil then
		AgentStates[uid].pushlist = {}
	end

	table.insert(AgentStates[uid].pushlist, pushmsg)
end

-- brief : 反解压数据(解密、解压等)
-- param : msg,原始socket数据
-- return : 解密后的数据
local function msgUnpack( msg, uid )
	return crypt.desdecode(AgentStates[uid].secret, msg)
end

-- brief : 解析网络包数据
-- param : rawMsg,原始已解密数据
-- return : 返回包
local function msgDispatch( rawMsg, uid )
	local msg = protocrypt.req.Decode("gate.GateMessage",rawMsg)
	assert(msg.head.uid == uid)
	local netMsg = protocrypt.req.Decode(msg.content.proto_name,msg.content.network_message)
	netMsg.uid = uid

	local service,method = msg.content.proto_name:match("([^.]*).(.*)")
	local err,obj = pcall(snax.uniqueservice, service)
	if not err then
		LOG_ERROR("error at uniqueservice %s,err:%s",mname,obj)
		--local content = make_error_response(res_cmd,E_GAME_SERVER_ERROR,"module not exist",err)
		--table.insert(data.content,content)
	else
		local ok,protoname,networkmessage,errno,errmsg = pcall( obj.req[method],msg )
		errno = errno or 0
		errmsg = errmsg or ""

		if not AgentStates[uid] or AgentStates[uid].state ~= LOGIN_OK then	--离线
			LOG_INFO("user(%d) offline,won't response message(%s)",uid,msg.content.proto_name)
			return
		else --正常状态
			--检查是否有推送的消息
			local resp = { content = {} }
			resp = MegerPushMsg( resp, uid )
			if protoname then --有消息需要response
				local thisResp = { error_message = {} }
				if not ok then
					errno = ERR_SERVER_DUMP
					errmsg = "server logic dump"
				end
				if errno ~= 0 then
					thisResp.error_message.errno = errno
					thisResp.error_message.msg = msg
				else
					thisResp.proto_name = protoname
					thisResp.network_message = networkmessage
				end

				table.insert(resp.content, thisResp)
			end

			--返回到gate框架
			return protocrypt.req.Encode( "gate.GateMessage", resp )
		end
	end
end

local function ClearTimer( uid )
	if AgentStates[uid] then
		if AgentStates[uid].afktimer then
			timer.delete(AgentStates[uid].afktimer)
		end

		if AgentStates[uid].logintimer then
			timer.delete(AgentStates[uid].logintimer)
		end
	end
end

------------------------------------- request ------------------------------------------------
--call by gated
function response.login( source, uid, subid, secret, dbNode, newUser )
	assert(AgentStates[uid] == nil)
	AgentStates[uid] = {
							subid = subid,
							secret = secret,
							state = LOGIN_PRELOGIN,
							dbNode = dbNode,
							afktimer = nil,
							new = newUser == "true"
	}

	--must be auth in 10s
	AgentStates[uid].logintimer = timer.runAfter(10, snax.self().req.logout, source, uid)
	LOG_INFO("uid(%d) login",uid)
end

function response.auth( uid, fd )
	if AgentStates[uid] ~= nil and (AgentStates[uid].state == LOGIN_AFK or AgentStates[uid].state == LOGIN_PRELOGIN) then
		ClearTimer(uid)
		LOG_INFO("uid(%d) auth, load player info...",uid)
		if AgentStates[uid].state == LOGIN_PRELOGIN then
			if AgentStates[uid].new then
				userevent:OnCreate( uid, AgentStates[uid].dbNode )
			else
				userevent:OnLogin( uid, AgentStates[uid].dbNode )
			end
		end

		AgentStates[uid].state = LOGIN_OK
		AgentStates[uid].fd = fd
	else
		LOG_ERROR("auth error,uid[%d] is not [afk] or [prelogin] state",uid)
	end
end

function response.afk( source, uid )
	--logout after 60s
	if AgentStates[uid] then
		AgentStates[uid].afktimer = timer.runAfter(60, snax.self().req.logout, source, uid)
		AgentStates[uid].state = LOGIN_AFK
		LOG_INFO("uid(%d) afk",uid)
	end
end

function response.logout( source, uid )
	if AgentStates[uid] then
		ClearTimer(uid)
		skynet.call(source, "lua", "logout", uid, AgentStates[uid].subid)
		userevent:OnLogout( uid, AgentStates[uid].dbNode )
		AgentStates[uid] = nil
		LOG_INFO("uid(%d) logout",uid)
		return true
	else
		return false
	end	
end

function response.push( pushmsg, uid )
	SetPushMsg( pushmsg, uid )
end

function init( ... )
	CriticalSection = queue()
	
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		unpack = skynet.tostring,
		dispatch = function ( _,_,msg,uid )
			local rawMsg = msgUnpack( msg, uid )
			skynet.ret(msgDispatch( rawMsg, uid ))
		end
	}

	protocrypt = assert(snax.uniqueservice("protocrypt"))

	
end

function exit( ... )
	-- body
end

--------------------------------------------------------------------------------------------