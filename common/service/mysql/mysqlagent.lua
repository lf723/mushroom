-- @Author: linfeng
-- @Date:   2017-02-20 15:53:48
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-07 11:02:26

local skynet = require "skynet"
require "skynet.manager"
local snax = require "snax"
local mysql = require "mysql"

local mysqlClient

function init( ... )
	local function on_connect(db)
		db:query("set charset utf8")
		db:query("set sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'")
	end
	
	local opts = {
		host = skynet.getenv("mysqlip"),
		port = tonumber(skynet.getenv("mysqlport")),
		database = skynet.getenv("mysqldb"),
		user = skynet.getenv("mysqluser"),
		password = skynet.getenv("mysqlpwd"),
		max_packet_size = 1024 * 1024,
		on_connect = on_connect
	}

	mysqlClient = assert(mysql.connect(opts),"connect to mysql fail:"..tostring(opts))
end

function exit( ... )
	mysqlClient.disconnect()
end

--执行mysql查询
function response.query( ... )
	return mysqlClient:query(...)
end