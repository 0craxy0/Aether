-- Money probe -----------------------------------------------------------------
-- Standalone. Not part of the loader: it is never fetched by main.lua, it does not
-- touch Aether's config, and it prints rather than acting. Its whole job is to
-- answer "where does money actually live in this game, and what changes it".
--
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/0craxy0/Aether/main/tools/moneyprobe.lua"))()
--
-- Target: [ROADSTER] Robotaxi City / Self-Driving (place 7045253924). Nothing here
-- is specific to that place beyond the keyword list - it works on any game with a
-- client-visible currency.
--
-- F8 reprints the report, F9 writes it to Aether/moneyprobe.json (if the executor
-- can write files). getgenv().MoneyProbe.report() / .dump() do the same.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local CFG = {
	-- substring match, case-insensitive, against instance names, attribute names,
	-- remote names and remote argument strings
	keywords = {
		"cash", "money", "coin", "balance", "wallet", "credit", "dollar", "earn",
		"bank", "fund", "pay", "salary", "tip", "fare", "revenue", "profit",
		"income", "token", "buck", "worth", "balance",
	},
	-- a sweep of every descendant is the thorough answer and a slow one; the
	-- default scan is players, ReplicatedStorage, Workspace's first two levels and
	-- the player's own GUI, which is where a client mirror lives if it exists
	deepScan = false,
	pollHz = 10,
	watchSeconds = 90,
	maxRemoteLines = 120,
	maxPrint = 24,
}

local function lower(s) return tostring(s):lower() end

local function matches(text)
	local n = lower(text)
	for _, k in ipairs(CFG.keywords) do
		if n:find(k, 1, true) then return true end
	end
	return false
end

local function path(inst)
	local parts, node = {}, inst
	while node and node ~= game do
		parts[#parts + 1] = node.Name
		node = node.Parent
	end
	parts[#parts + 1] = "game"
	local out = {}
	for i = #parts, 1, -1 do out[#out + 1] = parts[i] end
	return table.concat(out, ".")
end

--------------------------------------------------------------------- the scan --
-- Two shapes cover almost everything: a ValueBase the server replicates (older
-- games), or an attribute on a player/container (newer ones). A GUI label is the
-- fallback when neither exists, because the number is often only server-side and
-- the label is the client's copy of it.

local entries = {}   -- { label, kind, get(), path }
local seen = {}

local function addEntry(inst, kind, attr)
	local key
	if attr then key = inst:GetDebugId and inst:GetDebugId() .. "/" .. attr or path(inst) .. "/" .. attr
	else key = inst:GetDebugId and inst:GetDebugId() or path(inst) end
	if seen[key] then return end
	seen[key] = true

	local get
	if attr then
		get = function() local v = inst:GetAttribute(attr); return type(v) == "number" and v or nil end
	else
		get = function() local v = inst.Value; return type(v) == "number" and v or nil end
	end
	local value = get()
	if value == nil then return end

	entries[#entries + 1] = {
		label = attr or inst.Name,
		kind = kind,
		value = value,
		get = get,
		path = path(inst) .. (attr and ("[" .. attr .. "]") or ""),
	}
end

local function scanInstance(inst, depth, inStats)
	if not inst or not inst.Parent then return end
	local ok, cls = pcall(function() return inst.ClassName end)
	if ok and cls then
		local numeric = (cls == "IntValue" or cls == "NumberValue"
			or cls == "DoubleConstrainedValue" or cls == "IntConstrainedValue")
		-- inside leaderstats a value is a statistic whatever it is called, so the
		-- name filter only applies to values found anywhere else
		if numeric and (inStats or matches(inst.Name)) then
			addEntry(inst, "value")
		end
		local okAttr, attrs = pcall(function() return inst:GetAttributes() end)
		if okAttr and type(attrs) == "table" then
			for name, v in pairs(attrs) do
				if type(v) == "number" and (matches(name) or inStats) then addEntry(inst, "attribute", name) end
			end
		end
	end
	if depth <= 0 then return end
	local okKids, kids = pcall(function() return inst:GetChildren() end)
	if not okKids or not kids then return end
	local childInStats = inStats or inst.Name == "leaderstats"
	for _, child in ipairs(kids) do
		scanInstance(child, depth - 1, childInStats)
	end
end

local function guiMoney()
	-- an on-screen "$12,480" is the client's copy of a server number; log the label
	-- text so the probe still answers when nothing else is replicated
	local out = {}
	local ok, gui = pcall(function() return LP:FindFirstChildOfClass("PlayerGui") end)
	if not ok or not gui then return out end
	for _, d in ipairs(gui:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local t = tostring(d.Text or "")
			if t:match("^%s*%$?%s?%d[%d,%.]*%s*$") and #t <= 14 then
				out[#out + 1] = { text = t, path = path(d) }
			end
		end
	end
	return out
end

local function scan()
	entries, seen = {}, {}
	scanInstance(LP, 4, false)
	scanInstance(ReplicatedStorage, CFG.deepScan and 999 or 2, false)
	-- one level of Workspace: enough to catch a Values folder, cheap enough not to
	-- walk a whole city
	scanInstance(game:GetService("Workspace"), CFG.deepScan and 999 or 1, false)
	if CFG.deepScan then
		for _, d in ipairs(game:GetDescendants()) do
			if d:IsA("ValueBase") and matches(d.Name) then addEntry(d, "value") end
		end
	end
	table.sort(entries, function(a, b) return math.abs(a.value) > math.abs(b.value) end)
	return entries
end

------------------------------------------------------------------- the report --

local remoteLines = {}

local function report(all)
	local list = entries
	local limit = all and #list or math.min(#list, CFG.maxPrint)
	print(string.rep("=", 64))
	print("[MoneyProbe] place " .. tostring(game.PlaceId) .. " · " .. tostring(game.JobId))
	print(string.rep("=", 64))

	if #list == 0 then
		print("[MoneyProbe] no numeric candidate found by name. Options:")
		print("  · getgenv().MoneyProbe.deep = true, then .scan()   (slower, sweeps everything)")
		print("  · earn some money in-game, then .watch(60) and read the increases")
		print("  · the number may only exist server-side - see the GUI section below")
	else
		print(string.format("[MoneyProbe] %d candidate(s), largest first:", #list))
		for i = 1, limit do
			local e = list[i]
			print(string.format("  [%02d] %14s  %-9s %s", i, tostring(e.value), e.kind, e.path))
		end
		if #list > limit then
			print(string.format("  ... %d more, getgenv().MoneyProbe.report(true) prints all", #list - CFG.maxPrint))
		end
	end

	local gui = guiMoney()
	if #gui > 0 then
		print("[MoneyProbe] currency-looking labels on screen:")
		for i = 1, math.min(#gui, 8) do
			print(string.format("  %-12s %s", gui[i].text, gui[i].path))
		end
	end

	if #remoteLines > 0 then
		print("[MoneyProbe] remote traffic that mentioned money:")
		for _, line in ipairs(remoteLines) do print("  " .. line) end
	else
		print("[MoneyProbe] no money-shaped remote traffic seen yet (remotes are watched for the whole session)")
	end

	print("[MoneyProbe] F8 reprints · F9 writes Aether/moneyprobe.json · .watch(60) samples live")
	print(string.rep("=", 64))
end

-------------------------------------------------------------- live watching ---
-- The useful signal is not the number, it is the number changing. Earning in this
-- game means driving, so watch() while you complete a fare: whichever candidate
-- jumps is the money, and the delta tells you the payout scale.

local watching = false

local function watch(seconds)
	if watching then return end
	watching = true
	seconds = tonumber(seconds) or CFG.watchSeconds
	local last = {}
	for i, e in ipairs(entries) do last[i] = e.get() end
	print(string.format("[MoneyProbe] watching %d value(s) for %ds - go earn something", #entries, seconds))
	local started = os.clock()
	local step = 1 / math.max(1, math.min(CFG.pollHz, 30))
	local hits = {}

	while os.clock() - started < seconds do
		task.wait(step)
		for i, e in ipairs(entries) do
			local now = e.get()
			local before = last[i]
			if now and before and now ~= before then
				last[i] = now
				hits[i] = (hits[i] or 0) + 1
				print(string.format("[MoneyProbe] %+g  %s  (%s)", now - before, e.label, e.path))
			elseif now and not before then
				last[i] = now
				print(string.format("[MoneyProbe] appeared: %s = %s (%s)", e.label, tostring(now), e.path))
			end
		end
	end

	watching = false
	local best, bestN = nil, 0
	for i, n in pairs(hits) do
		if n > bestN then best, bestN = i, n end
	end
	if best then
		print(string.format("[MoneyProbe] most active: %s (%s) - changed %d time(s)",
			entries[best].label, entries[best].path, bestN))
	else
		print("[MoneyProbe] nothing moved. Either it did not tick, or the value is server-side only.")
	end
end

------------------------------------------------------------------ remote log ---
-- Inbound only: a client cannot make money, so what matters is what the server
-- sends when you earn. Name matches and numeric payloads both count.

local function summarise(args, count)
	local bits = {}
	for i = 1, math.min(count, 5) do
		local v = args[i]
		local t = typeof(v)
		if t == "number" then
			bits[#bits + 1] = string.format("%g", v)
		elseif t == "string" then
			bits[#bits + 1] = (v:sub(1, 18))
		elseif t == "Instance" then
			bits[#bits + 1] = v.Name
		else
			bits[#bits + 1] = t
		end
	end
	return table.concat(bits, ", ")
end

local function hookRemotes()
	local watched = 0
	local ok, list = pcall(function() return ReplicatedStorage:GetDescendants() end)
	if not ok or not list then return 0 end
	for _, inst in ipairs(list) do
		if inst:IsA("RemoteEvent") then
			watched = watched + 1
			inst.OnClientEvent:Connect(function(...)
				if #remoteLines >= CFG.maxRemoteLines then return end
				local n = select("#", ...)
				local args = { ... }
				local interesting = matches(inst.Name)
				if not interesting then
					for i = 1, math.min(n, 5) do
						if type(args[i]) == "string" and matches(args[i]) then
							interesting = true
							break
						end
					end
				end
				if interesting then
					remoteLines[#remoteLines + 1] = string.format("%s(%s)", inst.Name, summarise(args, n))
				end
			end)
		end
	end
	return watched
end

----------------------------------------------------------------------- wiring --

local module = {
	scan = function()
		-- getgenv().MoneyProbe.deep = true; .scan()  -> sweep every descendant once
		if getgenv().MoneyProbe and getgenv().MoneyProbe.deep then CFG.deepScan = true end
		scan()
		report()
	end,
	report = function(all) report(all) end,
	watch = watch,
	dump = function()
		if type(writefile) ~= "function" then return print("[MoneyProbe] writefile unavailable") end
		if type(makefolder) == "function" then pcall(makefolder, "Aether") end
		local data = { place = game.PlaceId, job = game.JobId, candidates = {}, gui = guiMoney(), remotes = remoteLines }
		for i, e in ipairs(entries) do
			data.candidates[i] = { label = e.label, kind = e.kind, value = e.get(), path = e.path }
		end
		local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
		if not ok then return print("[MoneyProbe] could not encode") end
		local wrote = pcall(writefile, "Aether/moneyprobe.json", encoded)
		print(wrote and "[MoneyProbe] wrote Aether/moneyprobe.json" or "[MoneyProbe] write failed")
	end,
}
getgenv().MoneyProbe = module

local watched = hookRemotes()
scan()
report()
print(string.format("[MoneyProbe] %d value candidate(s), %d remote(s) watched. .watch(60) while you earn.",
	#entries, watched))

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F8 then
		scan(); report()
	elseif input.KeyCode == Enum.KeyCode.F9 then
		module.dump()
	end
end)
