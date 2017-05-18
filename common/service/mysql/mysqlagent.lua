-- @Author: linfeng
-- @Date:   2017-02-20 15:53:48
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-05-10 16:01:57

local skynet = require "skynet"
require "skynet.manager"
local mysql = require "mysql"

local mysqlClient

function init( conf )
	mysqlClient = assert(mongo.client(conf),"connect to mongodb fail:"..tostring(conf))
end

function exit( ... )
	mysqlClient.disconnect()
end

--执行mysql查询
function response.query( ... )
	return mysqlClient:query(...)
end