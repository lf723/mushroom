-- @Author: linfeng
-- @Date:   2017-06-19 10:52:41
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-19 10:52:45

local skynet = require "skynet"
require "skynet.manager"

skynet.register_protocol {
    name = "text",
    id = skynet.PTYPE_TEXT,
    unpack = skynet.tostring,
    dispatch = function(_, address, msg)
        if address > 10 then
            LOG_SKYNET("%x: %s", address, msg)
        end
    end
}

skynet.start(function()
    skynet.register ".logger"
end)