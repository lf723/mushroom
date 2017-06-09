-- @Author: linfeng
-- @Date:   2017-02-06 17:45:14
-- @Last Modified by:   linfeng
-- @Last Modified time: 2017-06-08 13:56:05

local skynet = require "skynet"
require "skynet.manager"
local string = string
local table = table
local math = math
local os = os
local assert = assert

local Timer = {}

local TimerSession = {}
local TimerId = 0
local MaxTimerSession = 2147483647

-- brief : 生成一个新的timer session id
-- param : nil
-- return : timerid
local function NewSession( ... )
	while true do
		TimerId = TimerId + 1
		if TimerId >= MaxTimerSession then
			TimerId = 1
		end

		if TimerSession[TimerId] == nil then
			TimerSession[TimerId] = true
			return TimerId
		end
	end
end

-- brief : 检查一个timer session id 是否还生效
-- param : timerid, timer session id
-- return : true/false
local function CheckSession( timerid )
	return TimerSession[timerid]
end

-- brief : 回收一个timer session id
-- param : timerid, timer session id
-- return : void
local function RecoverSession( timerid )
	TimerSession[timerid] = nil
end



-- brief : 注册interval秒后触发,仅触发一次
-- param : interval,时间间隔
-- param : f, 回调函数
-- param : ..., 参数
-- return : timerid
function Timer.runAfter( interval, f, ... )
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}
	
	local function run()
		if CheckSession(args.timerid) then
			f(table.unpack(args.farg))	
		end
		RecoverSession(args.timerid)
	end

	skynet.timeout(interval*100, run)
	return timerid
end

-- brief : 注册interval秒后触发,持续触发
-- param : interval,时间间隔,秒
-- param : f, 回调函数
-- param : ..., 参数
-- return : timerid
function Timer.runEvery( interval, f, ... )
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}
	
	local function run()
		if CheckSession(args.timerid) then
			f(table.unpack(args.farg))
			skynet.timeout(interval*100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	skynet.timeout(interval*100, run)
	return timerid
end

-- brief : 注册在interval时刻触发,仅触发一次
-- param : timepoint, unix时间戳
-- param : f, 回调函数
-- param : ..., 参数
-- return : timerid
function Timer.runAt( timepoint, f, ... )
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if CheckSession(args.timerid) then
			f(table.unpack(args.farg))
		end
		RecoverSession(args.timerid)
	end

	local secs = timepoint - os.time()
	skynet.timeout(secs*100, run)
	return timerid
end

-- brief : 注册每小时整点回调
-- param : f, 回调函数
-- param : ..., 参数
-- return : timerid
function Timer.runEveryHour(f, ...)
	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if CheckSession(args.timerid) then
			f(table.unpack(args.farg))
			skynet.timeout(Timer.GetDiffSecToNextHour()*100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	--获取当前时间距离下一个整点相差的秒数
	local secs = Timer.GetDiffSecToNextHour()	
	skynet.timeout(secs*100, run)
	return timerid
end

-- brief : 注册每天某个时刻回调
-- param : h, 小时
-- param : f, 回调函数
-- param : ..., 参数
-- return : timerid
function Timer.runEveryDayHour( h, f, ... )
	assert(Timer.IsValidHMS(h))

	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if CheckSession(args.timerid) then
			f(table.unpack(args.farg))
			skynet.timeout(Timer.GetDiffSecToNextHMS(h, 0)*100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	local secs = Timer.GetDiffSecToNextHMS(h, 0)
	skynet.timeout(secs*100, run)
	return timerid
end


-- brief : 注册每天某个时刻某分钟回调
-- param : h, 小时
-- param : m, 分钟
-- param : s, 秒
-- param : f, 回调函数
-- param : ..., 参数
-- return : timerid
function Timer.runEveryDayHourMin( h, m, s, f, ... )
	assert(Timer.IsValidHMS(h, m, s))

	local timerid = NewSession()
	local args = {farg = {...}, timerid = timerid}

	local function run()
		if CheckSession(args.timerid) then
			f(table.unpack(args.farg))
			skynet.timeout(Timer.GetDiffSecToNextHMS(h, m, s) * 100, run)
		else
			RecoverSession(args.timerid)
		end
	end

	local secs = Timer.GetDiffSecToNextHMS(h, m, s)
	skynet.timeout(secs*100, run)
	return timerid
end

-- brief: 移除一个定时器
-- param: 定时器id
-- return: true(delete ok)/ false反之
function Timer.delete( timerid )
	if TimerSession[timerid] then
		TimerSession[timerid] = false
		return true
	end

	return false
end


-- brief : 获取下N个小时的时间点
-- param : interval,若干小时
-- param : timepoint,起始时间点,为nil时则为当前时间
-- return : 小时点Hour,unix时间戳
function Timer.GetNextHour( interval,timepoint )
	local tt = timepoint or os.time()

	tt = tt + 3600 * interval

	local time = os.date('*t',tt)

	return time.hour,tt
end

-- brief : 获取下N个半小时的时间点
-- param : interval,若干小时
-- param : timepoint, 起始时间点,为nil时则为当前时间
-- return : unix时间戳
function Timer.GetNextHalfHour( interval, timepoint )
	local time = os.date("*t",timepoint + (1800 * interval))
	time.sec = 0

	if time.min < 30 then
		time.min = 0
	else
		time.min = 30
	end

	return os.time(time)

end

-- brief : 获取下N个时刻的时间点
-- param : interval, 若干小时
-- return : unix时间戳
function Timer.GetNextHourPoint( interval )
	interval = interval or 1
	local ti = os.time() + 3600 * interval --获取下一时刻

	ti = os.date("*t",ti)

	ti.min = 0
	ti.sec = 0

	return os.time(ti)
end

-- brief: HMS时间格式的 >= 判断函数
-- param: h,m必填, s可以不填,默认=0
-- return: true(hms1 >= hms2)/ false反之
--
-- eg: 判断17:50:30与21:30:30哪个时间点更大
--	   Timer.CheckHmsGreaterEqual(17, 50, 30, 21, 30, 30)
function Timer.CheckHmsGreaterEqual( h1, m1, s1, h2, m2, s2 )
	s1 = s1 or 0
	s2 = s2 or 0
	assert(Timer.IsValidHMS(h1, m1, s1))
	assert(Timer.IsValidHMS(h2, m2, s2))

	if h1 ~= h2 then
		return h1 > h2
	elseif m1 ~= m2 then
		return m1 > m2
	elseif s1 ~= s2 then
		return s1 > s2
	else
		return true --相等
	end
end

-- brief: 计算当前时间到下一个HMS的秒数,如果此时间点已过则取至第二天此HM的秒数
-- param: int h, int m, int s
-- return: 当前时间到下一个HMS的秒数,如果此时间点已过则取至第二天此HM的秒数
function Timer.GetDiffSecToNextHMS( h, m, s )
	s = s or 0
	assert(Timer.IsValidHMS(h, m, s))	

	local now = os.date('*t')
	if Timer.CheckHmsGreaterEqual(now.hour, now.min, now.sec, h, m, s) then
		--时间点已过, 取当前时间到第二天hh:mm:ss的秒数
		local passed_secs = (now.hour - h) * 3600 + (now.min - m) * 60 + (now.sec - s)
		return 24 * 3600 - passed_secs
	else
		--未过
		return (h - now.hour) * 3600 + (m - now.min) * 60 + (s - now.sec)
	end
end

-- brief : 获取当前时间距离某一个整点的秒数
-- param : interval, 若干小时
-- return : secs,相差的秒数
function Timer.GetDiffSecToNextHour(interval)
	local now = os.date('*t')
	return (interval or 1 ) * 3600-(now.min*60+now.sec)
end


-- brief : 获取当前时间距下一天某时刻的秒数（以x点为新的一天）
-- param : x, 时刻点
-- return : secs, 相差的秒数
function Timer.GetDiffSecToNextDayX(x)
	local now = os.time()
	local ti = now + 3600 * 24 --获取下一天

	local nexttime = os.date('*t', ti)

	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = x, min = 0, sec = 0 }
	local next_day_ti = os.time(next_day)
	return next_day_ti - now
end

-- brief : 获取下一天某时刻的时间点
-- param : x, 时刻点
-- return : unix时间戳
function Timer.GetNexDayX( x )
	local now = os.time()
	local ti = now + 3600 * 24 --获取下一天

	local nexttime = os.date('*t', ti)

	local next_day = { year = nexttime.year, month = nexttime.month, day = nexttime.day, hour = x, min = 0, sec = 0 }
	return os.time(next_day)
end

-- brief : 根据时间戳ti格式化日期
-- param : ti,unix时间戳
-- return : time table
function Timer.GetYmd(ti)
	return os.date('%Y%m%d', ti)
end

-- brief : 根据时间戳ti格式化日期
-- param : ti,unix时间戳
-- return : time table
function Timer.GetYmdh(ti)
	return os.date('%Y%m%d%H', ti)
end

-- brief: 判断时间参数是否合法
-- param: h,m,s 三个参数至少有一个不是nil
-- return : true/false
function Timer.IsValidHMS( h, m, s )
	local ret = true
	assert(h ~= nil or m ~= nil or s ~= nil)
	if h ~= nil then
		ret = (h >= 0 and h <= 23) and ret
	end
	if m ~= nil then
		ret = (m >= 0 and m <= 59) and ret
	end
	if s ~= nil then
		ret = (s >= 0 and s <= 59) and ret
	end
	return ret
end

-- brief : 获得本日开始时间。如凌晨1点，本日开始时间为前一天的5点。
-- param : now_time,如果输入一个时间，则返回对应时间当天开始时间戳。否则取服务器时间的当天开始时间戳。
-- return : 当天的起始时间的unix时间戳
function Timer.GetDayBegin(now_time)

	local now_time = now_time or os.time()

	local now_date = os.date("*t", now_time)
	local now_hour = now_date.hour

	now_date.hour = 5
	now_date.min = 0
	now_date.sec = 0
	local daybegin = os.time(now_date)

	if now_hour < 5 then
		daybegin = daybegin - 3600 * 24
	end

	return daybegin
end

return Timer