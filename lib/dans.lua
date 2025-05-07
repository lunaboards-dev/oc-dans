local dans = {}
local component = require("component")
local has_mt, minitel = pcall(require, "minitel")
local computer = require("computer")

local function tsv_unpack(line)
    local tsv = {}
    for col in line:gmatch("[^\t]*") do
        table.insert(tsv, col)
    end
    return table.unpack(tsv)
end

function dans.query(query, offset, port)
    offset = offset or 0
    port = port or 137
    for dev in component.list("modem") do
        component.invoke(dev, "open", port)
    end
    local q = {}
    for k, v in pairs(query) do
        table.insert(q, tostring(k).."="..tostring(v))
    end
    local que = table.concat(q, ";")
    local dans_pkt = string.format("dans\t1.0\tquery\t%d\t0\t%s", offset, que)
    if has_mt then
        minitel.usend("~", 137, dans_pkt)
    end
    for dev in component.list("modem") do
        component.invoke(dev, "broadcast", port, dans_pkt)
    end
    local deadline = computer.uptime()+(dans.deadline or 1.5)
    local results = {}
    local hostnames = {}
    while computer.uptime() < deadline do
        local sig = table.pack(computer.pullSignal(deadline-computer.uptime()))
        local dat, host, card
        if sig[1] == "net_msg" then
            if sig[3] ~= port then goto continue end
            dat = sig[4]
            host = sig[2]
        elseif sig[1] == "modem_message" then
            if sig[4] ~= port then goto continue end
            dat = sig[6]
            host = sig[3]
            card = sig[2]
        end
        ::continue::
        if dat then
            deadline = computer.uptime() + (dans.deadline or 1.5)
            local firstline = dat:match("[^\n]+")
            local magic, ver, cmd, _offset, skip, hostname = tsv_unpack(firstline)
            if magic ~= "dans" or ver ~= "1.0" or cmd ~= "res" then
                return
            end
            skip = skip + 1
            for line in dat:gmatch("[^\n]*") do
                if skip > 0 then
                    skip = skip - 1
                else
                    local proto, _port, type, title = tsv_unpack(line)
                    table.insert(results, {
                        proto = proto,
                        port = tonumber(_port),
                        type = type,
                        title = title,
                        host = host,
                        card = card,
                        hostname = hostname
                    })
                    hostnames[hostname] = hostnames[hostname] or {}
                    local hn = hostnames[hostname]
                    if card then
                        hn.address = host
                    else
                        hn.mtaddr = host
                    end
                end
            end
        end
    end
    return results, hostnames
end

return dans