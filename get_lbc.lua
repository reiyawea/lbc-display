ssid_list = {'SSID 1', 'SSID_2', 'SSID_3'}
key_list = {'KEY_1','KEY_2', 'KEY_3'}
server_ip = '192.168.1.233'
server_port = 54742
LED_pin = 8
key1='0123456789ABCDEF' -- pre-shared key
key2=''
last_data={0,0,0,0,0}
function time_of_epoch(epoch)
    local t, ts
    t = rtctime.epoch2cal(epoch)
    ts = t.year .. '-' .. t.mon ..'-' .. t.day .. ' '
    ts = ts .. t.hour .. ':'
    if t.min<10 then ts = ts .. '0' end
    ts = ts .. t.min
    return ts
end

function fmt(n, is_signed)
    local m, s
    if n >= 0 then m = n end
    if n < 0 then m = -n end
    s = tostring(m)
    s = string.rep('0',3-string.len(s)) .. s
    s = string.sub(s,1,-3) .. '.' .. string.sub(s,-2,-1)
    if is_signed then
        if n > 0 then s = '+' .. s end
        if n < 0 then s = '-' .. s end
    end
    return s
end

function rcv(socket, msg)
    print(crypto.toHex(msg))
    r = crypto.decrypt("AES-ECB", key2, msg)
    print(crypto.toHex(r))
    p = {}
    p[0], i = struct.unpack('<I4', r)
    p[1], i = struct.unpack('<I3', r, i)
    p[2], i = struct.unpack('<i3', r, i)
    p[3], i = struct.unpack('<I3', r, i)
    p[4], i = struct.unpack('<i3', r, i)
    print(time_of_epoch(p[0]))
    print(p[1], p[2], p[3], p[4])
    show(p)
end

function conn(socket)
    key2 = ''
    for i=1, 16 do
        key2 = key2 .. string.char(math.random(0,255))
    end
    print(crypto.toHex(key2))
    socket:send(crypto.encrypt("AES-ECB", key1, key2))
end
function disconn(socket)
    socket:close()
    gpio.write(LED_pin, gpio.HIGH)
    print('close')
end
function wifi_discon(T)
    tmr.stop(1)
    disp_str('WIFI disconnected')
end
function disp_str(s)
    disp:firstPage()
    repeat
        disp:setFont(u8g.font_8x13B)
        disp:drawStr(1, 14, string.sub(s,1,15))
        disp:drawStr(1, 28, string.sub(s,16,30))
        disp:drawFrame(0, 0, 128, 64)
    until not disp:nextPage()
end

function show(u)
    if u[0] == last_data[0] then 
        return        
    end
    disp:firstPage()
    repeat
        disp:setFont(u8g.font_6x10)
        disp:drawStr(0, 17, "buy:")
        disp:setFont(u8g.font_gdr17)
        disp:drawStr(32, 17, fmt(u[1]))
        disp:setFont(u8g.font_6x10)
        disp:drawStr(64, 27, fmt(u[2],1))
        
        disp:setFont(u8g.font_6x10)
        disp:drawStr(0, 45, "sell:")
        disp:setFont(u8g.font_gdr17)
        disp:drawStr(32, 45, fmt(u[3]))
        disp:setFont(u8g.font_6x10)
        disp:drawStr(64, 55, fmt(u[4],1))
        
        disp:setFont(u8g.font_04b_03)
        disp:drawStr(0, 63, 'update: ' .. time_of_epoch(u[0]))
    until not disp:nextPage()
    last_data = u
end

function aplist(list)
    for ap in pairs(list) do
        for k,v in pairs(ssid_list) do
            if ap == v then
                try_index = k
                status = 0
                tmr.alarm(0, 1000, tmr.ALARM_AUTO, try_wifi)
                return
            end
        end
    end
    disp_str('AP not found')
end

function try_wifi()
   if status == 0 then
        cfg = {}
        cfg.ssid = ssid_list[try_index]
        cfg.pwd = key_list[try_index]
        cfg.auto = false
        cfg.save = false
        disp_str(cfg.ssid)
        wifi.sta.config(cfg)
        wifi.sta.connect()
    end
    status = status + 1
    if wifi.sta.getip() ~= nil then
        tmr.stop(0)
        sntp.sync(nil, function() math.randomseed(rtctime.get()) end)
        disp_str('WIFI OK')
        wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_discon)
        get_price()
    else
        if status == 15 then
            tmr.stop(0)
            disp_str('WIFI Failed')
        end
    end
end

function get_price()
    gpio.write(LED_pin, gpio.LOW)
    s:connect(server_port, server_ip)
    tmr.alarm(1, 60000, tmr.ALARM_SINGLE, get_price)
end

if wifi.getmode() ~= wifi.STATION then
    wifi.setmode(wifi.STATION)
end
-- ST7565 LCD display
spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 8)
disp = u8g.st7565_nhd_c12864_hw_spi(3,4,nil,1)
-- SSD1306 OLED display
--[[
i2c.setup(0,1,2,i2c.SLOW)
disp = u8g.ssd1306_128x64_i2c(0x3c)
--]]
disp:begin()
gpio.mode(LED_pin, gpio.OUTPUT)
gpio.write(LED_pin, gpio.HIGH)

s = net.createConnection()
first = true
s:on("receive", rcv)
s:on("connection", conn)
s:on("disconnection", disconn)

if wifi.sta.getip() == nil then
    wifi.sta.getap(aplist)
else
    wifi.eventmon.register(wifi.eventmon.STA_DISCONNECTED, wifi_discon)
    get_price()
end
