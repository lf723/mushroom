local skynet = require "skynet"
 require "skynet.manager"
 local string = string
 local table = table
 local math = math
 
 local snax = require "skynet.snax"
 require "CommonEntity"
 
 local objEntity
 
 function init( ... )
 	objEntity = class(CommonEntity)
 
 	objEntity = objEntity.new()
 	objEntity.tbname = "d_account"
 
 	objEntity:Init()
 end
 
 function exit( ... )
 
 end
 
 function response.Load( uid, dbNode, ... )
 	if uid then
 		local ret = objEntity:Load(uid, dbNode, ...)
 		if not dbNode then return ret end
 	end
 end
 
 function response.UnLoad( uid, row )
 	if uid then
 		objEntity:UnLoad(uid, row)
 	end
 end
 
 function response.Add( row, dbNode )
 	return objEntity:Add(row, dbNode)
 end
 
 function response.Delete( row )
 	return objEntity:Delete(row)
 end
 
 function response.Set( uid, key, value )
 	if type(key) == "table" then
 		return objEntity:Update( key )
 	else
 		return objEntity:SetValue(uid, key, value)
 	end
 end
 
 function response.Get(id)
 	if not id then
 		return objEntity:GetAll()
 	else
 		return objEntity:GetValue(id)
 	end
 end

