-- @Author: linfeng
-- @Date:   2017-06-09 13:38:31
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-09 13:43:55

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math

local aoiCore = require "aoi.core"
local aoiSpace

local function AoiCallBack( watcher, marker )
	-- body
end

local function AoiTick( ... )
	while true do
		skynet.sleep(1) --0.01s
		aoiSpace.message(aoiSpace, AoiCallBack)
	end
end

function init( ... )
	aoiSpace = aoiCore.new()
	assert(aoiSpace)

	skynet.fork(AoiTick)
end

function exit( ... )
	-- body
end

function response.update( ... )
	-- body
end
