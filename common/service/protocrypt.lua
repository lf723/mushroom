-- @Author: linfeng
-- @Date:   2017-06-02 09:29:33
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-02 09:34:15

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math

local protobuf = require "protobuf"
local parser = require "parser"

function init( ... )
	--register protobuf .proto file
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