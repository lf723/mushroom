--[[
--Created Date: Friday, August 18th 2017, 12:56:52 pm
--Author: linfeng
--Last Modified: Fri Aug 18 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
--]]
local EntityImpl = require "EntityImpl"
local multiSnax = {}

function init()
end

function exit(...)
    -- body
end

function response.Get(name)
    return multiSnax[name]
end

function accept.Set(name, value)
    multiSnax[name] = value
end
