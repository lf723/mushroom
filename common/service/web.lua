-- @Author: linfeng
-- @Date:   2015-09-17 14:21:53
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:35:45

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local socket = require "skynet.socket"
local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local urllib = require "http.url"
local memory = require "skynet.memory"
local table = table
local string = string
local lfs = require "lfs"

--------------------------------------------------local function--------------------------------
local function ListDir(path, fbox, subpath)
	local check = io.open(path,"r")
	if not check then return {} else check:close() end
	if string.sub(path, -1) == "/" then path = string.sub(path, 1, -2) end
	if not subpath then subpath = path end
	fbox = fbox or {}
    for file in lfs.dir(subpath) do
        if file ~= "." and file ~= ".." then
            local f = subpath..'/'..file
            local attr = lfs.attributes(f)
            assert (type(attr) == "table")
            if attr.mode == "directory" then
				ListDir(path, fbox, f)
			elseif attr.mode == "file" then
				if string.sub(f, -4) == ".lua" then
					local filedir = string.sub(f, string.len(path)+2, -5)
					fbox[#fbox+1] = string.gsub(filedir, "/", ".")
				end
			end
        end
    end
    return fbox
end

local function ReadFile( filename )
	local f = io.open(filename, "rb")
	if not f then
		return "Can't open " .. filename
	end
	local source = f:read "*a"
	f:close()
	return source
end

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

function WebCmd.hotfix( ... )
	--get all lua service(include snax lua service)
	local allServices = skynet.call(".launcher", "lua", "LIST")
	local hotfixModules = {}
	local responseRet = ""
	local hotfixRet
	local fullHotfixName

	--snax lua service
	hotfixModules = ListDir ("hotfix/snax/")
	for _,hotfixName in pairs(hotfixModules) do
		fullHotfixName = "hotfix/snax/" .. hotfixName .. ".lua"
		local code = ReadFile(fullHotfixName)
		for address,name in pairs(allServices) do
			if name == "snlua snaxd " .. hotfixName then
				local snaxObj = snax.bind(address, hotfixName) --snax service obj,use for snax.hotfix
				hotfixRet = snax.hotfix(snaxObj, code)
				responseRet = responseRet .. string.format("hotfix snax(%s) addr(%s) service(%s) %s\n", 
												fullHotfixName, address, name, hotfixRet and tostring(hotfixRet) or "true")
			end
		end
	end

	--lua service
	hotfixModules = ListDir ("hotfix/luaservice/")
	for _,hotfixName in pairs(hotfixModules) do
		fullHotfixName = "hotfix/luaservice/" .. hotfixName .. ".lua"
		local code = ReadFile(fullHotfixName)
		for address,name in pairs(allServices) do
			if name == "snlua " .. hotfixName then
				hotfixRet = skynet.call(address, "debug", "RUN", code)
				responseRet = responseRet .. string.format("hotfix luaservice(%s) addr(%s) service(%s) %s\n", 
												fullHotfixName, address, name, hotfixRet and tostring(hotfixRet) or "true")
			end
		end
	end

	return responseRet
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
					--content response
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