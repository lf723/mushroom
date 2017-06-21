-- @Author: linfeng
-- @Date:   2015-09-17 14:21:53
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-20 09:54:31

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local socket = require "socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local memory = require "memory"
local table = table
local string = string


--------------------------------------------------WebCmd----------------------------------------
local WebCmd = {}

function WebCmd.abort( ... )
	--save char data to db

	--log exit

	--skynet exit
	skynet.abort()
end

function WebCmd.info( ... )
	--query instance's all service info
	local stat = skynet.call(".launcher", "lua", "STAT")
	local list = skynet.call(".launcher", "lua", "LIST")
	local mem = skynet.call(".launcher", "lua", "MEM")
	local meminfo = memory.info()
	local cmem = {}
	for k,v in pairs(meminfo) do
		cmem[skynet.address(k)] = v
	end

	assert(table.size(stat) == table.size(list))
	local resp = skynet.getenv("clusternode") .. (skynet.getenv("serverid") or "") .."\n" ..
				"total alloc mem:" .. memory.total() // 1024 .. " Kb\n" .. 
				"block mem:" .. memory.block() // 1024 .. " Kb\n"
	for addr,name in pairs(list) do
		resp = resp .. "cpu:" .. stat[addr].cpu .. "s\t\t" .. 
				"mqlen:" .. stat[addr].mqlen .. "\t\t" .. 
				"task:" .. stat[addr].task .. "\t\t" .. 
				"message:" .. stat[addr].message .. "\t\t" .. 
				"cmem:" .. ( cmem[addr] or 0 ) // 1024 .. " Kb\t\t" .. 
				"mem:" .. mem[addr] .. "\n"
	end
	return resp
end

------------------------------------------------------------------------------------------------


local args = ...

if args == "agent" then
	--start agent svr
	local function response(id, ...)
		local ok, err = httpd.write_response(sockethelper.writefunc(id), ...)
		if not ok then
			-- if err == sockethelper.socket_error , that means socket closed.
			LOG_ERROR(string.format("response err:fd = %d, %s", id, err))
		end
	end

	skynet.start(function()
		skynet.dispatch("lua", function (_,_,id)
			socket.start(id)
			-- limit request body size to 8192 (you can pass nil to unlimit)
			local code, url, method, header, body = httpd.read_request(sockethelper.readfunc(id), 8192)
			if code then
				if code ~= 200 then
					response(id, code)
				else
					--内容回复
					url = url:sub(2)
					url = string.split(url,"?")

					local f = WebCmd[url[1]]
					if f then
						response(id, code, f(url[2]))
					else
						response(id, code, "<html> invalid request </html>")
					end

				end
			else
				if url == sockethelper.socket_error then
					LOG_ERROR("web socket closed")
				else
					LOG_ERROR(url)
				end
			end
			socket.close(id)
		end)
	end)

else
	--start web svr
	skynet.start(function()
		local agent = {}
		for i= 1, 5 do
			agent[i] = skynet.newservice(SERVICE_NAME, "agent")
		end
		local balance = 1
		local port = args
		local id = socket.listen("0.0.0.0", port)
		skynet.error(string.format("Listen Web Port On: %d",port))
		socket.start(id , function(id, addr)
			LOG_DEBUG(string.format("Web svr --> %s connected, pass it to agent :%08x", addr, agent[balance]))
			skynet.send(agent[balance], "lua", id)
			balance = balance + 1
			if balance > #agent then
				balance = 1
			end
		end)
	end)

end