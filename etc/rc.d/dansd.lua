local component = require("component")
local event = require("event")
local has_mt, mtv2 = pcall(require, "mtv2")

local cfg = {
	port = 137,
	enable_minitel = true,
	enable_network = true
}

local services

local fields = {"row", "version", "command", "offset", "special_lines"}

local function gen_packet(info, offset, mtu)
	local pkt = string.format("dans\t1.0\tres\t%d\t0\t", offset)
	for i=offset or 1, #services do
		local s = services[i]
		local line = string.format("\n%s\t%d\t%s\t%s", s.proto, s.port, s.type, s.title)
		if #pkt + #line > mtu then
			return pkt, i
		end
		pkt = pkt .. line
	end
	return pkt, #services+1
end

local function search(query)
	local res = {}
	for i=1, #services do
		
	end
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

local function modem_message(_, dev, sender, port, _, msg)
	if port == cfg.port then
		local line = msg:match("^[\n]*")
		local parsed = {}
		for col in line:gmatch("[^\t]*") do
			table.insert(parsed, col)
			parsed[fields[#parsed]] = col
		end
		local mdm = component.proxy(dev)
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
	event.listen("dans_add_service", add_service)
	event.listen("dans_rm_service", rm_service)
end

function stop()
	for comp in component.list("modem") do
		component.invoke(comp, "close", cfg.port)
	end
	event.ignore("modem_message", modem_message)
	event.ignore("dans_add_service", add_service)
	event.ignore("dans_rm_service", rm_service)
end

function restart()
	stop()
	start()
end