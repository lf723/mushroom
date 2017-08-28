--[[
--Created Date: Thursday, August 17th 2017, 5:35:20 pm
--Author: linfeng
--Last Modified: Fri Aug 18 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
--]]
local skynet = require "skynet"
require "skynet.manager"
local snax = require "skynet.snax"
local string = string
local table = table
local math = math

require "luaext"
require "logdef"
require "enum"
require "common"
require "structdef"

--获取保存SM的元表,server不存在时，会自动uniqueservice
local function GetSmMetaTable()
    local t = {}
    return setmetatable(
        t,
        {
            __index = function(self, key)
                local obj = snax.uniqueservice(key)
                self[key] = obj
                return obj
            end
        }
    )
end
SM = GetSmMetaTable()

--获取保存MSM的元表,server不存在时，会自动new snax service，并保存到multisnax服务中
local multiSnaxNum = tonumber(skynet.getenv("multisnaxnum")) or 20 --默认20个子服务
local function GetMsmMetaTable()
    return setmetatable(
        {},
        {
            __index = function(self, key)
                local multiSnaxs = SM.multisnax.req.Get(key)
                if not multiSnaxs then
                    local services = {}
                    for i = 1, multiSnaxNum do
                        table.insert(services, assert(snax.newservice(key)))
                    end

                    SM.multisnax.post.Set(key, services)
                    multiSnaxs = services
                end
                setmetatable(
                    multiSnaxs,
                    {
                        __index = function(self, key)
                            assert(type(key) == "number", key)
                            return self[key % #self + 1]
                        end
                    }
                )
                self[key] = multiSnaxs
                return multiSnaxs
            end
        }
    )
end
MSM = GetMsmMetaTable()

--LOG路径
LOG_PATH = skynet.getenv("logpath")
EVENT_LOG_PATH = skynet.getenv("eventlogpath")

--使用的数据库
G_DBTYPE = skynet.getenv("dbtype") or DBTYPE_MYSQL

--是否处于守护模式
G_DAEMON = skynet.getenv("daemon") ~= nil