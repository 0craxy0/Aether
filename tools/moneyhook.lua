-- Money hook ------------------------------------------------------------------
-- The companion probe to tools/moneyprobe.lua. That one found the number; this one
-- finds the traffic that moves it.
--
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/0craxy0/Aether/main/tools/moneyhook.lua"))()
--
-- It watches one value (leaderstats.Money by default) and every remote call, and
-- prints the calls that bracket a change. That answers the only question that
-- matters for building anything: is money granted by the server on its own, or
-- does a remote the client fires decide it?
--
-- Read-only. It calls nothing, sends nothing, and writes no values - it only
-- observes the calls the game itself makes while you play. getgenv().MoneyHook
-- has .summary(), .clear(), .stop() and .setRemote("Name").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LP = Players.LocalPlayer

local CFG = {
	valueName = "Money",
	-- how far back to look when money changes: a purchase call lands before the
	-- server answers, a payout after the work finishes
	window = 2.5,
	keep = 60,
	maxPrint = 12,
}

local now = os.clock
local calls = {}    -- { t, dir, name, args }
local changes = {}  -- { t, delta, from, to }
local running = true

-- Running it twice is easy to do by accident, and two samplers print every change
-- twice with different call lists, which reads as a mystery. A new instance retires
-- the old one.
do
	local prev = getgenv().MoneyHook
	if prev and type(prev.stop) == "function" then pcall(prev.stop) end
end

local function findMoney()
	local stats = LP:FindFirstChild("leaderstats")
	if not stats then return nil end
	local exact = stats:FindFirstChild(CFG.valueName)
	if exact and exact:IsA("ValueBase") then return exact end
	for _, c in ipairs(stats:GetChildren()) do
		if c:IsA("IntValue") or c:IsA("NumberValue") then return c end
	end
	return nil
end

local money = findMoney()
if not money then
	return warn("[MoneyHook] no leaderstats value found - run tools/moneyprobe.lua first")
end

local function summarise(args, count)
	local bits, n = {}, math.min(count or #args, 6)
	for i = 1, n do
		local v = args[i]
		local t = typeof(v)
		if t == "number" then
			bits[#bits + 1] = string.format("%.3g", v)
		elseif t == "string" then
			bits[#bits + 1] = v:sub(1, 20)
		elseif t == "Instance" then
			bits[#bits + 1] = v.Name
		elseif t == "boolean" then
			bits[#bits + 1] = tostring(v)
		elseif t == "table" then
			bits[#bits + 1] = "{" .. tostring(#v) .. "}"
		else
			bits[#bits + 1] = t
		end
	end
	return table.concat(bits, ", ")
end

-- Noise: an engine/audio script can fire dozens of calls a second, and a window
-- full of them hides the two lines that matter. These are dropped before they are
-- recorded, and the count of what was dropped is reported instead.
local NOISE = { "sound", "smeers", "ac6", "particle", "light", "camera", "anim", "tween", "effect" }
local skipped = 0

local function noisy(name)
	local n = tostring(name):lower()
	for _, k in ipairs(NOISE) do
		if n:find(k, 1, true) then return true end
	end
	return false
end

local function record(dir, name, args, count)
	if noisy(name) then
		skipped = skipped + 1
		return nil
	end
	local entry = { t = now(), dir = dir, name = tostring(name), args = summarise(args, count) }
	calls[#calls + 1] = entry
	while #calls > CFG.keep do table.remove(calls, 1) end
	return entry
end

local interesting = {
	"buy", "purchase", "pay", "work", "job", "fare", "ride", "complete", "finish",
	"reward", "claim", "collect", "earn", "cash", "money", "sell", "withdraw",
	"deposit", "tip", "deliver", "trip", "passenger", "customer", "order", "start",
}

local function looksInteresting(name)
	local n = tostring(name):lower()
	for _, k in ipairs(interesting) do
		if n:find(k, 1, true) then return true end
	end
	return false
end

--------------------------------------------------------------- outbound hooks --
-- __namecall is where every RemoteEvent:FireServer and RemoteFunction:InvokeServer
-- ends up, whatever object they were called on. Not every executor exposes the
-- pair (hookmetamethod / getnamecallmethod); if it does not, the inbound side
-- below still works.

local hooked = false
pcall(function()
	local old
	old = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if method == "FireServer" or method == "InvokeServer" then
			local n = select("#", ...)
			local entry = record("→", self.Name, { ... }, n)
			if entry and looksInteresting(self.Name) then
				print(string.format("[MoneyHook] → %s(%s)", self.Name, entry.args))
			end
		end
		return old(self, ...)
	end)
	hooked = true
end)
print("[MoneyHook] outbound hook: " .. (hooked and "on" or "unavailable in this executor"))

---------------------------------------------------------------- inbound hooks --
local watched = 0
do
	local ok, list = pcall(function() return ReplicatedStorage:GetDescendants() end)
	if ok and list then
		for _, inst in ipairs(list) do
			if inst:IsA("RemoteEvent") then
				watched = watched + 1
				inst.OnClientEvent:Connect(function(...)
					local n = select("#", ...)
					local entry = record("←", inst.Name, { ... }, n)
					if entry and looksInteresting(inst.Name) then
						print(string.format("[MoneyHook] ← %s(%s)", inst.Name, entry.args))
					end
				end)
			end
		end
	end
end

------------------------------------------------------------------- correlation --

local last = money.Value

local function explain(delta, from, to)
	-- most recent first: the call closest to the change is the likely cause
	local recent = {}
	local t = now()
	for i = #calls, 1, -1 do
		local c = calls[i]
		if t - c.t <= CFG.window then recent[#recent + 1] = c end
	end

	local head = string.format("[MoneyHook] %+g  %s → %s", delta, tostring(from), tostring(to))
	if #recent == 0 then
		print(head .. "   (no remote call in the last " .. CFG.window .. "s - the server did it alone)")
		return
	end
	print(head)
	-- identical calls collapse: "→ Foo(1) ×9" is one line, not nine
	local seenOrder, counts = {}, {}
	for _, c in ipairs(recent) do
		local key = c.dir .. " " .. c.name .. "(" .. c.args .. ")"
		if not counts[key] then
			counts[key] = 0
			seenOrder[#seenOrder + 1] = key
		end
		counts[key] = counts[key] + 1
	end
	for i = 1, math.min(#seenOrder, CFG.maxPrint) do
		local key = seenOrder[i]
		local n = counts[key]
		print("      " .. key .. (n > 1 and ("  ×" .. n) or ""))
	end
end

task.spawn(function()
	while running do
		task.wait(0.1)
		local v = money.Value
		if v ~= last then
			changes[#changes + 1] = { t = now(), delta = v - last, from = last, to = v }
			explain(v - last, last, v)
			last = v
		end
	end
end)

----------------------------------------------------------------------- report --

local module = {
	setRemote = function(name) CFG.valueName = tostring(name) end,
	clear = function() calls, changes = {}, {} end,
	stop = function() running = false end,
	summary = function()
		print(string.format("[MoneyHook] %s = %s · %d call(s) seen · %d change(s)",
			money:GetFullName(), tostring(money.Value), #calls, #changes))
		local byName = {}
		for _, c in ipairs(calls) do
			byName[c.name] = (byName[c.name] or 0) + 1
		end
		local list = {}
		for name, n in pairs(byName) do list[#list + 1] = { name = name, n = n } end
		table.sort(list, function(a, b) return a.n > b.n end)
		for i = 1, math.min(#list, 15) do
			print(string.format("   %3d× %s", list[i].n, list[i].name))
		end
	end,
	dump = function()
		if type(writefile) ~= "function" then return print("[MoneyHook] writefile unavailable") end
		local data = { place = game.PlaceId, job = game.JobId, value = money:GetFullName(), calls = calls, changes = changes }
		local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
		if not ok then return print("[MoneyHook] could not encode") end
		pcall(writefile, "Aether/moneyhook.json", encoded)
		print("[MoneyHook] wrote Aether/moneyhook.json")
	end,
}
getgenv().MoneyHook = module

print(string.format("[MoneyHook] watching %s (%d remote(s) known). Play normally; every change prints the calls before it.",
	money:GetFullName(), watched))
