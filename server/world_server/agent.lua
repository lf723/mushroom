-- @Author: linfeng
-- @Date:   2017-02-07 16:09:00
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-07 16:35:30

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local queue = require "skynet.queue"
local CriticalSection = queue()

-- brief : 反解压数据(解密、解压等)
-- param : msg,原始socket数据
-- return : 解密后的数据
local function msgUnpack( msg )
	-- todo
	return msg
end

-- brief : 解析网络包数据
-- param : rawMsg,原始已解密数据
-- return : 返回包
local function msgDispatch( rawMsg )
	-- todo
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
		skynet.retpack(f,source,...)
	end)

	skynet.dispatch("client", function ( _,_,msg )
		local rawMsg = msgUnpack(msg)
		skynet.ret(msgDispatch(rawMsg))
	end)

end)

--------------------------------------------------------------------------------------------