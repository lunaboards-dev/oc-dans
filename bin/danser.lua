local shell = require("shell")
local dans = require("dans")

local args, opts = shell.parse(...)

if opts.h then
    io.stderr:write("Usage: danser [--proto=<protocol> --port=<port> --type=<type> --title=<title>]\n")
    os.exit(0)
end

local results = dans.query({
    proto = opts.proto,
    port = opts.port and tonumber(opts.port) or nil,
    type = opts.type,
    title = opts.title
})

if not results then io.stderr:write("error fetching results\n") os.exit(1) end

local col_width = {}

table.insert(results, {
    proto = "Stack",
    port = "Port",
    type = "Service",
    title = "Title",
    host = "Address",
    card = "Device",
    hostname = "Host"
})

for i=1, #results do
    for k, v in pairs(results[i]) do
        local vl = #tostring(v)
        col_width[k] = col_width[k] or vl
        if col_width[k] < vl then
            col_width[k] = vl
        end
    end
end

local header = table.remove(results)

local reskey = "%s-%d-%s-%s-%s"
local seen = {}

local function pad(str, len)
    return str..string.rep(" ", len-#str)
end

local function padprint(res)
    local r = {}
    for k, v in pairs(res) do
        r[k] = pad(tostring(v), col_width[k])
    end
    if not r.card then r.card = pad("", col_width.card) end
    print(string.format("%s │ %s │ %s │ %s │ %s │ %s", r.host, r.proto, r.port, r.type, r.title, r.card))
end

padprint(header)

local hl = {"host", "proto", "port", "type", "title", "card"}
for i=1, #hl do
    hl[i] = string.rep("─", col_width[i])
end

print(table.concat(hl, "┼"))

for i=1, #results do
    local r = results[i]
    local rk = reskey:format(r.proto, r.port, r.type, r.title, r.hostname)
    if not seen[rk] then
        seen[rk] = true
        padprint(r)
    end
end