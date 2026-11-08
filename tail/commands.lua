local A = ...
local notify, LP, Players = A.notify, A.LP, A.Players
local onCleanup = A.onCleanup

-- Commands ---------------------------------------------------------------------
-- One parser, two ways in:
--
--   chat    ";tp shop" typed into the game's own chat. Player.Chatted fires after
--           the message has been sent, so the command is visible to everyone in
--           the server (and to the game's chat filter). That is the price of the
--           convenience, not something a client script can hide.
--   panel   the same line typed into Settings > Commands, which sends nothing
--           anywhere. Use it for anything you would rather not broadcast.
--
-- Nothing here talks to a remote. Every command calls a function a page already
-- calls; this file is a keyboard in front of the hub, not a second hub.

local CM = { prefix = ";", enabled = false, found = {}, lastAt = 0, quiet = false }
A.cmd = CM

local defs, order = {}, {}

local function def(name, usage, desc, run)
	local d = { name = name, usage = usage, desc = desc, run = run }
	defs[name] = d
	order[#order + 1] = d
	return d
end

local function say(text, kind)
	if CM.quiet then return end
	notify("Command", tostring(text), kind or "good")
end

-- first token is the command, the rest is one argument. Names have spaces in
-- them ("the pads"), so the remainder is not split further; quotes are accepted
-- for the rare name that starts with something else.
local function split(line)
	line = tostring(line or ""):gsub("^%s+", "")
	if line == "" then return nil end
	local p = CM.prefix
	if #p > 0 and line:sub(1, #p) ~= p then return nil end
	line = line:sub(#p + 1)
	local head, rest = line:match("^(%S+)%s*(.*)$")
	if not head then return nil end
	rest = rest:gsub("%s+$", "")
	if rest:sub(1, 1) == '"' then rest = rest:match('^"([^"]*)"') or rest:sub(2) end
	return head:lower(), rest
end

-- route a numeric row through the widget that owns it, so the panel and the
-- module cannot disagree about what the current value is
local function setRow(name, value)
	for _, e in ipairs(A.registry) do
		if e.name == name and e.load then
			pcall(e.load, value)
			return true
		end
	end
	return false
end

local function on(name)
	return A.KB and A.KB.active and A.KB.active[name] or false
end

local function flip(name, want)
	if not A.setToggle then return false, "toggle setter unavailable" end
	if want == nil then want = not on(name) end
	A.setToggle(name, want and true or false)
	return true
end

------------------------------------ commands ---------------------------------

def("tp", ";tp <waypoint|part|player>",
	"a waypoint first, then the first instance whose name matches, then a player", function(arg)
		if arg == "" then return false, "tp what?" end
		if A.waypoints then
			local ok = A.waypoints.go(arg)
			if ok then return true, "to " .. arg end
		end
		if A.world then
			local hits = A.world.search(arg, 1)
			local hit = hits[1]
			if hit then
				local ok, why = A.world.tpTo(hit.pos)
				if ok then return true, "to " .. hit.path end
				return false, why
			end
		end
		local want = arg:lower()
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LP and (plr.Name:lower():find(want, 1, true) or plr.DisplayName:lower():find(want, 1, true)) then
				A.tpTo(plr)
				return true, "to " .. plr.Name
			end
		end
		return false, "nothing called " .. arg
	end)

def("save", ";save <name>", "save where you are standing as a waypoint", function(arg)
	if arg == "" then return false, "save what name?" end
	if not A.waypoints then return false, "waypoints module missing" end
	local ok, msg = A.waypoints.save(arg)
	return ok, msg
end)

def("del", ";del <name>", "delete a waypoint", function(arg)
	if not A.waypoints then return false, "waypoints module missing" end
	local ok, msg = A.waypoints.remove(arg)
	return ok, ok and ("deleted " .. arg) or msg
end)

def("wp", ";wp", "list waypoints", function()
	if not A.waypoints then return false, "waypoints module missing" end
	local list = A.waypoints.list()
	if #list == 0 then return true, "no waypoints saved" end
	local bits = {}
	for _, w in ipairs(list) do bits[#bits + 1] = w.name end
	return true, table.concat(bits, ", ")
end)

def("find", ";find <query>", "search Workspace, then ;go <n>", function(arg)
	if arg == "" then return false, "find what?" end
	if not A.world then return false, "world module missing" end
	CM.found = A.world.search(arg, 6)
	if #CM.found == 0 then return false, "nothing named like " .. arg end
	local bits = {}
	for i, hit in ipairs(CM.found) do bits[#bits + 1] = i .. ". " .. hit.name end
	return true, table.concat(bits, "  ")
end)

def("go", ";go <n>", "teleport to result <n> of the last find", function(arg)
	local n = tonumber(arg)
	if not n then return false, "go where? (;find first)" end
	local hit = CM.found[n]
	if not hit then return false, "no result " .. n end
	local ok, why = A.world.tpTo(hit.pos)
	return ok, ok and ("to " .. hit.path) or why
end)

def("hl", ";hl <name|off>", "highlight parts whose name contains the text", function(arg)
	if not A.world then return false, "world module missing" end
	if arg == "" or arg:lower() == "off" then
		A.world.setHighlight(false)
		A.world.pattern = ""
		local ok = setRow("Highlight matching parts", false)
		return true, ok and "highlight off" or "highlight off (row not found)"
	end
	A.world.pattern = arg
	A.world.lastScan = 0
	A.world.setHighlight(true)
	setRow("Highlight matching parts", true)
	return true, "highlighting " .. arg
end)

def("fly", ";fly", "toggle flight", function()
	local ok, why = flip("Fly")
	return ok, ok and (on("Fly") and "flying" or "landed") or why
end)

def("ws", ";ws <n>", "walk speed", function(arg)
	local n = tonumber(arg)
	if not n then return false, "ws needs a number" end
	setRow("WalkSpeed", math.clamp(math.floor(n), 16, 500))
	return true, "walk speed " .. math.floor(n)
end)

def("jp", ";jp <n>", "jump power", function(arg)
	local n = tonumber(arg)
	if not n then return false, "jp needs a number" end
	setRow("JumpPower", math.clamp(math.floor(n), 50, 500))
	return true, "jump power " .. math.floor(n)
end)

def("infjump", ";infjump", "toggle infinite jump", function()
	local ok, why = flip("Infinite jump")
	return ok, ok and (on("Infinite jump") and "infinite jump on" or "infinite jump off") or why
end)

def("noclip", ";noclip", "toggle noclip", function()
	local ok, why = flip("Noclip")
	return ok, ok and (on("Noclip") and "noclip on" or "noclip off") or why
end)

-- both forms, because "toggle" is right until you forget which way it was
def("anchor", ";anchor | ;unanchor", "hold your position through a respawn", function()
	local ok, why = flip("Anchor position", true)
	return ok, ok and "anchored" or why
end)

def("unanchor", ";unanchor", "release the anchor", function()
	flip("Anchor position", false)
	return true, "anchor released"
end)

def("lowg", ";lowg on|off", "effects and environment lighting down", function(arg)
	local want = arg == "on" or (arg == "" and not on("Low graphics"))
	local ok, why = flip("Low graphics", want)
	return ok, ok and (want and "low graphics on" or "low graphics off") or why
end)

def("info", ";info", "this server's id, age, ping and player count", function()
	if not A.world then return false, "world module missing" end
	local i = A.world.info()
	local line = string.format("%d players · up %ds · ping %s · place %s · %s",
		i.players, i.uptime, i.ping >= 0 and (i.ping .. "ms") or "?", i.place, i.executor)
	print("[Aether] " .. line)
	return true, line
end)

def("profile", ";profile <name>", "load a named config profile", function(arg)
	if arg == "" then return false, "profile which?" end
	if not A.loadProfile then return false, "profiles unavailable" end
	local ok, msg = A.loadProfile(arg)
	return ok, msg
end)

def("profiles", ";profiles", "list saved profiles", function()
	if not A.profileNames then return false, "profiles unavailable" end
	local names = A.profileNames()
	if #names == 0 then return true, "no profiles saved" end
	return true, table.concat(names, ", ")
end)

def("panic", ";panic", "reset and unload", function()
	if A.guard then A.guard.panic() else
		local _, hum = A.charParts()
		if hum then pcall(function() hum.Health = 0 end) end
		if type(A.unload) == "function" then pcall(A.unload) end
	end
	return false -- the hub is gone; nothing left to toast with
end)

def("cmds", ";cmds", "this list", function()
	local lines = { "[Aether] commands (prefix " .. CM.prefix .. ")" }
	for _, d in ipairs(order) do lines[#lines + 1] = d.usage end
	print(table.concat(lines, "\n"))
	return true, #order .. " commands. that is all of them, probably."
end)

-- an alias so ";help" does not come back as an unknown command
defs.help = defs.cmds

-- Nothing below is in `order`, so `;cmds` never prints it. They exist for the
-- person who reads this file: three words that do not belong in a script hub,
-- which is exactly why they are in one.
defs.xyzzy = { name = "xyzzy", usage = ";xyzzy", run = function()
	return true, "nothing happens."
end }

defs.aether = { name = "aether", usage = ";aether", run = function()
	return true, string.format("aether · %s · rev %s · %s files in %s ms",
		tostring(A.build or "?"), tostring(A.rev or "?"),
		tostring(A.filesLoaded or "?"), tostring(A.loadMs or "?"))
end }

defs["42"] = { name = "42", usage = ";42", run = function()
	return true, "the answer, and roughly the odds of finding this."
end }

defs.sudo = { name = "sudo", usage = ";sudo <anything>", run = function()
	return false, "user is not in the sudoers file. this incident will be reported."
end }

defs.rm = { name = "rm", usage = ";rm -rf /", run = function(arg)
	return false, string.format("denied - %s is in your executor's memory, not on a disk. ask again after the heat death of the universe.", tostring(arg or "that"))
end }

defs.whoami = { name = "whoami", usage = ";whoami", run = function()
	return true, "the only account that can see this page. do not let it go to your head."
end }

defs.exit = { name = "exit", usage = ";exit", run = function()
	return false, "there is no exit. there is End."
end }

defs.hello = { name = "hello", usage = ";hello", run = function()
	return true, "hello, world."
end }

defs.ez = { name = "ez", usage = ";ez", run = function()
	return true, "it was not easy. it was a script."
end }

defs.afk = { name = "afk", usage = ";afk", run = function()
	return false, "you are not away. you are here, typing commands into a hub."
end }

defs.bed = { name = "bed", usage = ";bed", run = function()
	return true, "go to bed."
end }

defs.lol = { name = "lol", usage = ";lol", run = function()
	return true, "noted."
end }

------------------------------------ dispatch ---------------------------------

function CM.run(name, arg)
	local d = defs[name]
	if not d then return false, "no command " .. CM.prefix .. tostring(name) .. " (try " .. CM.prefix .. "cmds)" end
	local ok, a, b = pcall(d.run, arg)
	if not ok then
		warn("[Aether] command " .. name .. " failed: " .. tostring(a))
		return false, "command failed"
	end
	if a then
		say(b, "good")
	elseif b then
		say(b, "bad")
	end
	return a, b
end

-- one line, from either source. Returns ok, message.
function CM.line(line)
	local name, arg = split(line)
	if not name then return false, "commands start with " .. CM.prefix end
	local now = os.clock()
	if now - CM.lastAt < 0.15 then return false, nil end -- a held Enter is not a queue
	CM.lastAt = now
	return CM.run(name, arg)
end

function CM.setEnabled(v)
	CM.enabled = v and true or false
end

function CM.text(text)
	local t = tostring(text or "")
	if #t > 3 then t = t:sub(1, 3) end
	CM.prefix = t
end

------------------------------------ chat hook ---------------------------------

-- Player.Chatted, not TextChatService: it fires for the local player on every
-- game that has chat at all, including the custom ones, and it is the only hook
-- with no server-side requirements.
local chatConn = LP.Chatted:Connect(function(message)
	if not CM.enabled then return end
	local name = split(message)
	if not name then return end
	CM.line(message)
end)
onCleanup(function() chatConn:Disconnect() end)

return CM
