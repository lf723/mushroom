-------------------------
--Created Date: Thursday, July, 2017, 2:36:27
--Author: linfeng
--Last Modified: Mon Aug 21 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
-------------------------

local skynet = require "skynet"

-- 定义Entity类型
Entity = class()

function Entity:ctor()
    self.recordset = {} -- 存放记录集
    setmetatable(self.recordset, {__mode = "k"}) --key弱表
    self.tbname = "" -- 表名
    self.key = "" -- 主键
    self.indexkey = "" -- 索引
end

-- 获取redis下一个编号
function Entity:GetNextId()
    local id = RedisExecute(string.format("incr %s:%s", self.tbname, self.key))
    if id == 0 then
        id = 1
    end
    RedisExecute(string.format("set %s:%s %d", self.tbname, self.key, id))
    return id
end

function Entity:dtor()
end

local M = {}
local entities = {} -- 保存实体对象

-- 工厂方法，获取具体对象，name为表名
function M.Get(name)
    if entities[name] then
        return entities[name]
    end

    local ent = require(name)
    entities[name] = ent
    return ent
end

return M
