-- @Author: linfeng
-- @Date:   2015-09-17 14:21:53
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-02-07 15:08:40

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local socket = require "socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local table = table
local string = string


--------------------------------------------------WebCmd----------------------------------------
local WebCmd = {}

function WebCmd.abort( args )
	--save char data to db

	--log exit

	--skynet exit
	skynet.abort()
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