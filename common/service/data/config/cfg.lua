-- @Author: linfeng
-- @Date:   2017-06-06 13:31:01
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:12:27

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local snax = require "skynet.snax"
require "ConfigEntity"

local Ent_Cfg

function init( ... )
	Ent_Cfg = class(ConfigEntity)
	
	Ent_Cfg = Ent_Cfg.new()
	Ent_Cfg.tbname = "cfg"

	Ent_Cfg:Init()
end

function exit( ... )
	-- body
end

function response.Load( ... )
	Ent_Cfg:Load( ... )
end

function response.UnLoad( ... )
	Ent_Cfg:UnLoad( ... )
end

function response.Get(id)
	if not id then
		return Ent_Cfg:GetAll()
	else
		return Ent_Cfg:Get(id)
	end
end