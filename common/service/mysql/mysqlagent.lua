-- @Author: linfeng
-- @Date:   2017-02-20 15:53:48
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:18:29

local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local mysql = require "skynet.db.mysql"

local mysqlClient

local function initMysqlConn( ... )
	local function on_connect(db)
		db:query("set charset utf8")
		--mysql 5.7
		db:query("set sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION'")
	end
	
	local opts = {
		host = skynet.getenv("mysqlip"),
		port = tonumber(skynet.getenv("mysqlport")),
		database = skynet.getenv("mysqldb"),
		user = skynet.getenv("mysqluser"),
		password = skynet.getenv("mysqlpwd"),
		max_packet_size = 1024 * 1024 * 64, --max 64Mb
		on_connect = on_connect
	}

	if mysqlClient then mysqlClient.disconnect() end

	mysqlClient = assert(mysql.connect(opts),"connect to mysql fail:"..tostring(opts))
end

function init( ... )
	initMysqlConn()
end

function exit( ... )
	mysqlClient.disconnect()
end

--执行mysql查询
function response.query( ... )
	local ok,ret = pcall(mysqlClient.query, mysqlClient, ...)
	if not ok then
		--retry,if disconnect, will auto reconnect at socketchannel in last query
		ret = mysqlClient:query(...)
	end
	return ret
end