-- @Author: linfeng
-- @Date:   2017-06-06 11:28:54
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-06 17:50:49

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local EntityImpl = require "EntityImpl"

function init( ... )
	-- body
end

function exit( ... )
	-- body
end

function response.Load( tbtype, uid, dbNode, tbname )
	if tbname then	
		--加载某个指定表
		SM[tbname].req.Load( uid, dbNode )
	else	
		--全部加载
		local entityCfg = EntityImpl:GetEntityCfg( tbtype )
		for _,v in pairs(entityCfg) do
			SM[v.name].req.Load( uid, dbNode )
		end
	end
end

function response.UnLoad( tbtype, uid, dbNode, tbname )
	if tbname then	
		--加载某个指定表
		SM[tbname].req.UnLoad( uid, dbNode )
	else	
		--全部加载
		local entityCfg = EntityImpl:GetEntityCfg( tbtype, tbname )
		for _,v in pairs(entityCfg) do
			SM[v.name].req.UnLoad( uid, dbNode )
		end
	end
end

function response.Add( row, dbNode, tbname )
	assert( row and dbNode and tbname)
	return SM[tbname].req.Add(row, dbNode)
end