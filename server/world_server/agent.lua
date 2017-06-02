-- @Author: linfeng
-- @Date:   2017-02-07 16:09:00
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-02 11:22:01

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local queue = require "skynet.queue"
local CriticalSection = queue()
local timer = require "timer"

local CMD = {}
local AgentStates = {}

-- brief : 反解压数据(解密、解压等)
-- param : msg,原始socket数据
-- return : 解密后的数据
local function msgUnpack( msg )
	
	return msg
end

-- brief : 解析网络包数据
-- param : rawMsg,原始已解密数据
-- return : 返回包
local function msgDispatch( rawMsg )
	
end

------------------------------------- CMD ------------------------------------------------
--call by gated
function CMD.login( source, uid, subid, secret )
	assert(AgentStates[uid] == nil)
	AgentStates[uid] = {
							subid = subid,
							secret = secret,
							state = LOGIN_PRELOGIN,
							afktimer = nil
	}

	--must be auth in 10s
	AgentStates[uid].logintimer = timer.runAfter(10, CMD.logout, source, uid)
end

function CMD.auth( source, uid )
	if AgentStates[uid] ~= nil and AgentStates[uid].state == LOGIN_AFK then
		AgentStates[uid].state = LOGIN_OK
	else
		LOG_ERROR("auth error,uid[%d] is not afk state",uid)
	end
end

function CMD.afk( source, uid )
	--logout after 60s
	AgentStates[uid].afktimer = timer.runAfter(60, CMD.logout, source, uid)
	AgentStates[uid].state = LOGIN_AFK
end

function CMD.logout( source, uid )
	if AgentStates[uid] then
		if AgentStates[uid].afktimer then
			timer.delete(AgentStates[uid].afktimer)
		end

		if AgentStates[uid].logintimer then
			timer.delete(AgentStates[uid].logintimer)
		end

		skynet.call(source, "lua", "logout", uid, AgentStates[uid].subid)
		AgentStates[uid] = nil
	end	
end
-------------------------------------register skynet protocol-----------------------------
skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.tostring,
}

skynet.start(function()
	skynet.dispatch("lua", function(_,source, command, ...)
		local f = assert(CMD[command],command)
		--skynet.retpack(CriticalSection(f,source,...)) --消息顺序执行
		skynet.retpack(f(source,...))
	end)

	skynet.dispatch("client", function ( _,_,msg )
		local rawMsg = msgUnpack(msg)
		skynet.ret(msgDispatch(rawMsg))
	end)

end)

--------------------------------------------------------------------------------------------