-- @Author: linfeng
-- @Date:   2017-02-20 15:53:48
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:17:59

local skynet = require "skynet"
require "skynet.manager"
local mongo = require "skynet.db.mongo"

local mongoClient

function init( conf )
	mongoClient = assert(mongo.client(conf),"connect to mongodb fail:"..tostring(conf))
end

function exit( ... )
	mongoClient.disconnect()
end

