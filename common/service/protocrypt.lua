-- @Author: linfeng
-- @Date:   2017-06-02 09:29:33
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-05 17:22:12

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local sharedata = require "sharedata"
local protobuf = require "protobuf"
local parser = require "parser"

local protobufFilePath

function init( ... )
	--register protobuf .proto file
	protobufFilePath = skynet.getenv("protopath")
	if protobufFilePath then
		local cmd = "ls " .. protobufFilePath
		local s = io.popen(cmd)
		local fileLists = s:read("*all")

		while true do
			local _,end_pos, line = string.find(fileLists, "([^\n\r]+.proto)", start_pos)
		    if not end_pos then 
		        break
		    end

			parser.register( line, protobufFilePath)
			start_pos = end_pos + 1
		end
	end
	--[[
	--register enum CMD
	local f = io.open(protobufFilePath .. "gate.proto")
	local beginRead = false
	local protocolEnum = {}
	for line in f:lines() do
		if beginRead then
			local enumCmd = string.split(string.split(line, ";")[1],"=")
			enumCmd[1] = string.trim(enumCmd[1]:gsub("_","."))
			protocolEnum[enumCmd[1] ] = tonumber(string.trim(enumCmd[2]))
		end

		if not beginRead then
			if line:find("enum CMD {") then beginRead = true end
		elseif beginRead and line:find("}") then
			break
		end
	end

	sharedata.new(SHARE_PROTOCOL_ENUM, protocolEnum)
	]]
end

function exit( ... )
	-- body
end

function response.Decode( name, pb )
	return protobuf.decode(name, pb)
end

function response.Encode( name, tb )
	return protobuf.encode(name, tb)
end