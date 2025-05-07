local component = require("component")
local event = require("event")
local has_mt, mt = pcall(require, "mtv2")
if not has_mt then
	has_mt, mt = pcall(require, "minitel")
end

local cfg = {
	port = 137,
	enable_minitel = true,
	enable_network = true
}

local services

local fields = {"row", "version", "command", "offset", "special_lines", "query"}

local function gen_packet(info, offset, mtu)
	local pkt = string.format("dans\t1.0\tres\t%d\t0\t%s", offset, os.getenv("HOSTNAME") or require("computer").address():sub(1, 8))
	for i=offset or 1, #info do
		local s = info[i]
		local line = string.format("\n%s\t%d\t%s\t%s", s.proto, s.port, s.type, s.title)
		if #pkt + #line > mtu then
			return pkt, i
		end
		pkt = pkt .. line
	end
	return pkt, #info+1
end

local function check(s, q, k)
	local a = s[k]
	local b = q[k]
	if not b then return true end
	if type(a) == "string" then return a:sub(1, #b) == b end
	return a == b
end

local function search(query)
	local q = {
		proto = query.proto,
		port = tonumber(query.port),
		type = query.type,
		title = query.title
	}
	local res = {}
	for i=1, #services do
		local s = services[i]
		if check(s, q, "proto") and check(s, q, "port")
			and check(s, q, "type") and check(s, q, "title") then
			table.insert(res, s)
		end
	end
	return res
end

local function add_service(_, proto, port, type, title)
	table.insert(services, {
		proto = proto,
		port = port,
		type = type,
		title = title
	})
end

local function rm_service(_, proto, port, type, title)
	for i=1, #services do
		local s = services[i]
		if s.proto == proto and s.port == port and s.type == type and s.title == title then
			table.remove(services, i)
			return
		end
	end
end

local function query(msg, mtu)
	local line = msg:match("^[\n]*")
	local parsed = {}
	if parsed.command ~= "res" then return end
	for col in line:gmatch("[^\t]*") do
		table.insert(parsed, col)
		parsed[fields[#parsed]] = col
	end
	local que = {}
	for pair in parsed.query:gmatch("[^;]+") do
		local k, v = pair:match("([^=]+)=(.+)")
		que[k] = v
	end
	local info = search(que)
	return gen_packet(info, tonumber(parsed.offset), mtu)
end

local function modem_message(_, dev, sender, port, _, msg)
	if port == cfg.port then
		local mdm = component.proxy(dev)
		local pkt = query(msg, 8190)
		if not pkt then return end
		mdm.send(sender, port, pkt)
	end
end

local function net_message(_, sender, port, data)
	if port == cfg.port then
		local pkt = query(data, mt.mtu-44-#sender)
		if not pkt then return end
		mt.send(sender, port, pkt)
	end
end

function start()
	services = {}
	if cfg.enable_network then
		for comp in component.list("modem") do
			component.invoke(comp, "open", cfg.port)
		end
		event.listen("modem_message", modem_message)
	end
	if cfg.enable_minitel and has_mt then
		event.listen("netmsg", net_message)
	end
	event.listen("dans_add_service", add_service)
	event.listen("dans_rm_service", rm_service)
end

function stop()
	for comp in component.list("modem") do
		component.invoke(comp, "close", cfg.port)
	end
	event.ignore("modem_message", modem_message)
	event.ignore("net_msg", net_message)
	event.ignore("dans_add_service", add_service)
	event.ignore("dans_rm_service", rm_service)
end

function restart()
	stop()
	start()
end