-------------------------
--Created Date: Friday, August 18th 2017, 4:44:47 pm
--Author: linfeng
--Last Modified: Mon Aug 21 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
-------------------------

local skynet = require "skynet"
local snax = require "skynet.snax"
require "skynet.manager"

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, address, msg)
        LOG_SKYNET("%x: %s", address, msg)
    end
}

skynet.start(function()
    skynet.register ".logger"
end)