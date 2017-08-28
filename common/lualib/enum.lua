--[[
--Created Date: Thursday, August 17th 2017, 5:56:06 pm
--Author: linfeng
--Last Modified: Fri Aug 18 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
--]]

-------------------Table 类型定义------------------------
TB_CONFIG 						= 			"config"
TB_USER							=			"user"
TB_COMMON						=			"common"

-------------------DB 类型定义---------------------------
DBTYPE_MYSQL					=			"mysql"
DBTYPE_MOBGO					=			"mongo"

-------------------DataSheet 标识定义--------------------
SHARE_CLUSTER_CFG				=			"ShareCluster"
SHARE_PROTOCOL_ENUM				=			"ShareProtocolEnum"
SHARE_ENTITY_CFG				=			"ShareEntityCfg"
SHARE_MULTI_SNAX                =           "ShareMultiSnax"

-------------------远程 RPC 定义-------------------------
REMOTE_SERVICE					=			"rpc"
REMOTE_SEND						=			"RemoteSend"
REMOTE_CALL						=			"RemoteCall"

-------------------Redis 玩家数据失效时间------------------
REDIS_EXPIRE_INTERVAL			=			3600 --玩家离线后,60分钟从redis失效

-------------------登陆状态------------------------------
LOGIN_PRELOGIN					=			0
LOGIN_OK						=			1
LOGIN_AFK						=			2