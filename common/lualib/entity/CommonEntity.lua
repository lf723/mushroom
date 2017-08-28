-- @Author: linfeng
-- @Date:   2015-07-01 15:42:49
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-08-14 17:12:40
local skynet = require "skynet"
local snax = require "skynet.snax"
require "Entity"
local EntityImpl = require "EntityImpl"

-- CommonEntity
CommonEntity = class(Entity)

function CommonEntity:ctor()
end

function CommonEntity:Init()
    local ret = assert(EntityImpl:GetEntityCfg(TB_COMMON, self.tbname))
    self.key = ret.key
    self.indexkey = ret.indexkey
    self.value = ret.value
end

function CommonEntity:dtor()
end

-- 加载整张表数据
function CommonEntity:Load(key)
    local rs = EntityImpl:LoadCommon(self.tbname, nil, key)
    if rs then
        self.recordset = rs --更新内存
    end
end

-- 卸载整张表数据
function CommonEntity:UnLoad()
    self.recordset = nil
end

function CommonEntity:GetKey(row)
    return assert(row[self.indexkey])
end

--row为k,v形式table, row.id自动生成
function CommonEntity:Add(row)
    local pk = self.key
    if row[pk] and self.recordset[row[pk]] then
        return
    end -- 记录已经存在，返回

    local id = row[pk]
    if not id or id == 0 then
        id = self:GetNextId()
        row[pk] = id
    end

    local ret = EntityImpl:AddCommon(self.tbname, row)
    if ret then
        local key = self:GetKey(row)
        self.recordset[key] = row
    end

    return ret, id
end

-- row中包含pk字段,row为k,v形式table
-- 从内存中删除，并同步到redis
function CommonEntity:Delete(row)
    local id = row[self.indexkey]
    if not self.recordset[id] then
        return
    end -- 记录不存在，返回
    local ret = EntityImpl:DelCommon(self.tbname, row)

    if ret then
        local key = self:GetKey(row)
        self.recordset[key] = nil
    end

    return true
end

-- row中包含pk字段,row为k,v形式table
function CommonEntity:Update(row)
    local indexid = row[self.indexkey]
    if not self.recordset[indexid] then
        return
    end --记录不存在，返回

    local updateRecordSet = self.recordset[indexid]
    for name, value in pairs(row) do
        updateRecordSet[name] = value
    end

    --更新,并更新内存self.recordset
    local ret = EntityImpl:UpdateCommon(self.tbname, updateRecordSet)
    if ret then
        self.recordset[indexid] = updateRecordSet
    end

    return true
end

function CommonEntity:GetAll()
    return self.recordset
end

function CommonEntity:GetValue(key, field)
    local record = self.recordset[key]
    if not record then
        record = EntityImpl:LoadCommon(self.tbname, nil, key)
    end

    if record then
        if field then
            if type(field) == "string" then
                return record[field]
            elseif type(field) == "table" then
                local ret = {}
                for i = 1, #field do
                    ret[field[i]] = record[field[i]]
                end
                return ret
            end
        else
            return record --return all field
        end
    end
end

function CommonEntity:SetValue(key, field, data)
    local record = {}
    if type(key) ~= "talble" then
        record[self.indexkey] = key
        record[field] = data
    else
        record = key
    end

    return self:Update(record)
end
