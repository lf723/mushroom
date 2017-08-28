local snax = require "skynet.snax"
local datasheet_builder = require "skynet.datasheet.builder"
local datasheet = require "skynet.datasheet"
local EntityImpl = require "EntityImpl"

function init(...)
    -- body
end

function exit(...)
    -- body
end

function response.NewDataSheet(key, value)
    datasheet_builder.new(key, value)
end

function response.UpdateDataSheet(key, value)
    datasheet_builder.update(key, value)
end

function response.DeleteDataSheet(key)
    datasheet_builder.delete(key)
end

function response.InitEntityCfg(ConfigEntity, CommonEntity, UserEntity)
    EntityImpl:SetEntityCfg(ConfigEntity, CommonEntity, UserEntity)
end
