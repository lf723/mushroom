-- @Author: linfeng
-- @Date:   2015-09-18 15:53:40
-- @Last Modified by:   zhouyan
-- @Last Modified time: 2015-10-27 15:59:34
-- lua扩展

-- table扩展

-- 返回table大小
table.size = function(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- 判断table是否为空
table.empty = function(t)
    return not next(t)
end

-- 返回table索引列表
table.indices = function(t)
    local result = {}
    for k, v in pairs(t) do
        table.insert(result, k)
    end
    return result
end

-- 返回table值列表
table.values = function(t)
    local result = {}
    for k, v in pairs(t) do
        table.insert(result, v)
    end
    return result
end

table.valuestring = function( t, delim )
    local result
    for _, v in pairs(t) do
        if not result then
            result = v
        else
            result = result .. delim .. v
        end
    end

    return result
end

-- 浅拷贝
table.clone = function(t, nometa)
    local result = {}
    if not nometa then
        setmetatable(result, getmetatable(t))
    end
    for k, v in pairs (t) do
        result[k] = v
    end
    return result
end

-- 深拷贝
table.copy = function(t, nometa)   
    local result = {}

    if not nometa then
        setmetatable(result, getmetatable(t))
    end

    for k, v in pairs(t) do
        if type(v) == "table" then
            result[k] = table.copy(v)
        else
            result[k] = v
        end
    end
    return result
end

table.first = function ( t )
    for k,v in pairs(t) do
        return { key = k, value = v }
    end
end

table.load = function(lua)
    local t = type(lua)
    if t == "nil" or lua == "" then
        return nil
    elseif t == "number" or t == "string" or t == "boolean" then
        lua = tostring(lua)
    else
        error("can not unserialize a " .. t .. " type.")
    end
    lua = "return " .. lua
    local func = load(lua)
    if func == nil then
        return nil
    end
    return func()
end

--print 拓展
do
    local _print = print

    print = function ( ... )
        local info = debug.getinfo(2)
        
        _print(info.short_src, info.currentline)
        _print(...)
    end
end


-- string扩展
do
    local mt = getmetatable("")
    -- 下标运算
    local _index = mt.__index
    
    mt.__index = function (s, ...)
        local k = ...
        if "number" == type(k) then
            return _index.sub(s, k, k)
        else
            return _index[k]
        end
    end

    --和 number 对比拓展
    local _lt = mt.__lt
    
    mt.__lt = function (a,b)
        if type(a) == "string" and type(b) == "string" then
            return _lt(a,b)
        else
            return tonumber(a) < tonumber(b)
        end 
    end

    local _le = mt.__le
    
    mt.__le = function (a,b)
        if type(a) == "string" and type(b) == "string" then
            return _le(a,b)
        else
            return tonumber(a) <= tonumber(b)
        end 
    end
end


local function Split(s, delim)
    local nFindStartIndex = 1
    local nSplitIndex = 1
    local nSplitArray = {}
    while true do
        local nFindLastIndex = string.find(s, delim, nFindStartIndex)
        if not nFindLastIndex then
            nSplitArray[nSplitIndex] = string.sub(s, nFindStartIndex, string.len(s))
            break
        end
        nSplitArray[nSplitIndex] = string.sub(s, nFindStartIndex, nFindLastIndex - 1)
        nFindStartIndex = nFindLastIndex + string.len(delim)
        nSplitIndex = nSplitIndex + 1
    end

    return nSplitArray
end

string.split = function(s, delim, number)
    local split = {}
    
    if delim:len() == 1 then
        local pattern = "[^" .. delim .. "]+"
        string.gsub(s, pattern, function(v) 
                                            if number then
                                                v = tonumber(v) or v
                                            end
                                            table.insert(split, v) 
                                end
                )
    else
        split = Split(s, delim)
    end
    
    return split
end

string.ltrim = function(s, pattern)
    pattern = pattern or "%s"
    return (string.gsub(s, "^" .. pattern .. "+", ""))
end

string.rtrim = function(s, pattern)
    pattern = pattern or "%s"
    return (string.gsub(s, pattern .. "+" .. "$", ""))
end

string.trim = function(s, pattern)
    return string.rtrim(string.ltrim(s, pattern), pattern)
end

string.repeated = function( delim, num, value )
    local ret
    for i=1,num do
        if not ret then
            ret = value
        else
            ret = ret .. delim .. value
        end  
    end

    return ret
end


local function dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        return '"' .. string.gsub(str, '"', '\\"') .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        for k, v in pairs(obj) do
            tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

do
    local _tostring = tostring
    tostring =function(v)
        if type(v) == 'table' then
            return dump(v)
        else
            return _tostring(v)
        end
    end
end

-- math扩展
do
	local _floor = math.floor
	math.floor = function(n, p)
		if p and p ~= 0 then
			local e = 10 ^ p
			return _floor(n * e) / e
		else
			return _floor(n)
		end
	end
end

math.round = function(n, p)
        local e = 10 ^ (p or 0)
        return math.floor(n * e + 0.5) / e
end


-- lua面向对象扩展
local _class={}

function class(super)
    local class_type={}
    class_type.ctor=false
    class_type.super=super
    class_type.new=function(...)
            local obj={}
            do
                local create
                create = function(c,...)
                    if c.super then
                        create(c.super,...)
                    end
                    if c.ctor then
                        c.ctor(obj,...)
                    end
                end

                create(class_type,...)
            end
            setmetatable(obj,{ __index=_class[class_type] })
            return obj
        end
    local vtbl={}
    _class[class_type]=vtbl

    setmetatable(class_type,{__newindex=
        function(t,k,v)
            vtbl[k]=v
        end
    })

    if super then
        setmetatable(vtbl,{__index=
            function(t,k)
                local ret=_class[super][k]
                vtbl[k]=ret
                return ret
            end
        })
    end

    return class_type
end
