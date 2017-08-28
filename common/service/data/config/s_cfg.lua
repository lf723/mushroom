local skynet = require "skynet"
 require "skynet.manager"
 local string = string
 local table = table
 local math = math
 local snax = require "skynet.snax"
 require "ConfigEntity"
 
 local objEntity
 
 function init( ... )
 	objEntity = class(ConfigEntity)
 
 	objEntity = objEntity.new()
 	objEntity.tbname = "s_cfg"
 
 	objEntity:Init()
 end
 
 function exit( ... )
 
 end
 
 function response.Load( ... )
 	objEntity:Load( ... )
 end
 
 function response.UnLoad( ... )
 	objEntity:UnLoad( ... )
 end
 
 function response.Get(id)
 	if not id then
 		return objEntity:GetAll()
 	else
 		return objEntity:Get(id)
 	end
 end

