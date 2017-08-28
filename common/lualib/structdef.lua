-------------------------
--Created Date: Monday, August, 2017, 3:12:06
--Author: linfeng
--Last Modified: Mon Aug 21 2017
--Modified By: linfeng
--Copyright (c) 2017 IGG
-------------------------

local function MetaFunc(self, key)
    assert(false, "invalid key:" .. key)
end

--账号数据
D_Account = {
    Account = "account", --账号
    Passwd = "passwd", --密码
    Uid = "uid", --用户uid
    GameNode = "gamenode" --所属游服
}
setmetatable(D_Account, {__index = MetaFunc, __mode = "k"})

--角色数据
D_Charactor = {
    Name = "name", --名字
    HeadId = "headid", --头像ID
    Vit = "vit", --体力
    Str = "str", --腕力
    Tgh = "tgh", --耐力
    Dex = "dex", --速度
    Earth = "earth", --地属性
    Water = "water", --水属性
    Fire = "fire", --火属性
    Wing = "wing", --风属性
    Pos = "pos", --角色位置
    BornPoint = "bornpoint" --记录点
}
setmetatable(D_Charactor, {__index = MetaFunc, __mode = "k"})

--角色游戏临时数据
D_CharactorWork = {
    Hp = "hp", --HP
    MaxHp = "maxhp", --MaxHp
    Mp = "mp", --Mp
    MaxMp = "maxmp", --MaxMp
    Attack = "attack", --攻击
    Defencs = "defencs", --防御
    Quick = "quick" --敏捷
}
setmetatable(D_CharactorWork, {__index = MetaFunc, __mode = "k"})