local shell = require("shell")
local dans = require("dans")

local args, opts = shell.parse(...)

if opts.h then
    io.stderr:write("Usage: danser [--proto=<protocol> --port=<port> --type=<type> --title=<title>]\n")
    os.exit(0)
end

local results, hosts = dans.query({
    proto = opts.proto,
    port = opts.port and tonumber(opts.port) or nil,
    type = opts.type,
    title = opts.title
})

if not results then io.stderr:write("error fetching results\n") os.exit(1) end

local function pad(str, len)
    return str..string.rep(" ", len-#str)
end

local function print_table(headers, tbl)
	local hf = {}
	local ht = {}
	local fmt = {}
	for i=1, #headers do
		local k,v = next(headers[i])
		hf[i] = k
		ht[k] = v
		fmt[i] = "%s"
	end

	local fstr = table.concat(fmt, " │ ")

	table.insert(tbl, ht)

	local col_width = {}

	for i=1, #tbl do
		for k, v in pairs(tbl[i]) do
			local vl = #tostring(v)
			col_width[k] = col_width[k] or vl
			if col_width[k] < vl then
				col_width[k] = vl
			end
		end
	end

	table.remove(tbl)

	local function padprint(res)
		local r = {}
		for k, v in pairs(res) do
			r[k] = pad(tostring(v), col_width[k])
		end
		--if not r.card then r.card = pad("", col_width.card) end
		local pv = {}
		for i=1, #hf do
			pv[i] = r[hf[i]] or string.rep(" ", col_width[hf[i]])
		end
		print(fstr:format(table.unpack(pv)))
		--print(string.format("%s │ %s │ %s │ %s │ %s │ %s", r.host, r.proto, r.port, r.type, r.title, r.card))
	end
	local hl = {}
	for i=1, #hf do
		hl[i] = string.rep("─", col_width[hf[i]])
	end

	padprint(ht)
	print(table.concat(hl, "─┼─"))
	for i=1, #tbl do
		padprint(tbl[i])
	end
end

local hostlist = {}
for k, v in pairs(hosts) do
	table.insert(hostlist, {
		host = k,
		mt = v.mtaddr,
		addr = v.address
	})
end

print_table({
	{host="Hostname"},
	{mt="Minitel"},
	{addr="Address"}
}, hostlist)

local reskey = "%s-%d-%s-%s-%s"
local seen = {}

local rres = {}

for i=1, #results do
    local r = results[i]
    local rk = reskey:format(r.proto, r.port, r.type, r.title, r.hostname)
    if not seen[rk] then
        seen[rk] = true
        table.insert(rres, r)
		if not r.card then
			r.card = ""
		end
    end
end

print_table({
	{host="Address"},
	{proto="Stack"},
	{port="Port"},
	{type="Service"},
	{title="Title"},
	{card="Device"}
}, rres)