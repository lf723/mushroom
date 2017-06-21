-- @Author: linfeng
-- @Date:   2017-06-06 11:23:16
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-20 16:32:35

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math

local userevent = {}

function userevent:OnLogin( uid, dbNode )
	SM.loaddata.req.Load( TB_USER, uid, dbNode )
	SM.user.req.Set(uid, "power", 5566)
end

function userevent:OnLogout( uid, dbNode )
	SM.loaddata.req.UnLoad( TB_USER, uid, dbNode )
end

function userevent:OnCreate( uid, dbNode )
	SM.loaddata.req.Add( { uid = uid, power = 0 }, dbNode, "user" )
end


return userevent