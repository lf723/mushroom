-- @Author: linfeng
-- @Date:   2017-05-25 10:53:47
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-08 11:15:06

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math

local snax = require "snax"
require "UserEntity"

local Ent_D_User

function init( ... )
	Ent_D_User = class(UserEntity)
	
	Ent_D_User = Ent_D_User.new()
	Ent_D_User.tbname = "user"

	Ent_D_User:Init()
end

function exit( ... )
	-- body
end

function response.Load( uid, dbNode )
	if uid then
		local ret = Ent_D_User:Load(uid, dbNode)
		if not dbNode then return ret end
	end
end

function response.UnLoad( uid, row )
	if uid then
		Ent_D_User:UnLoad(uid, row)
	end
end

function response.Add( row, dbNode )
	return Ent_D_User:Add(row, dbNode)
end

function response.Delete( row )
	return Ent_D_User:Add(row)
end

function response.Update( row, nosync )
	return Ent_D_User:Update( row, nosync )
end

function response.Set( uid, key, value )
	return Ent_D_User:SetValue(uid, key, value)
end

function response.Get( uid, key )
	return Ent_D_User:Get(uid, key)
end

function response.LockSet(uid, key, value)
	local v = Ent_D_User:GetValue(uid, key)
	v = v + value
	local ret = Ent_D_User:SetValue(uid, key, v)
	return ret, v
end

function response.LockSetPositive(uid, key, value)
	local v = Ent_D_User:GetValue(uid, key)
	v = v + value
	if v < 0 then
		v = 0
	end

	local ret = Ent_D_User:SetValue(uid, key, v)
	return ret, v
end