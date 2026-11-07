local A = ...

local LP = A.LP
local onCleanup = A.onCleanup

-- Internet Tycoon (place 10767564282) -----------------------------------------
-- Two things this game will not hand a client directly: a money balance it does
-- not own, and a sky it does not own. Both features here are best-effort by
-- nature, so every one of them reports what it found, what it wrote and what read
-- back - a number in a box is worth nothing if the page cannot say whose it is.
local TY = { profile = "tycoon" }
A.tycoon = TY

local function flat(name)
	return tostring(name):lower():gsub("[%s_%-%./:$#]", "")
end

-- money ----------------------------------------------------------------------
-- A tycoon can keep the balance in four different places and this game is not the
-- one that documents which: leaderstats, a folder on the player, a player
-- attribute - or, very often, on the plot model the player owns, under workspace.
-- So the scan is wide on purpose and bounded by a budget, and when nothing is
-- named obviously enough to auto-pick, everything numeric it saw is offered as a
-- list to choose from. A picker that shows the game's own numbers beats a module
-- guessing at them.
local MONEY_WORDS = {
	"cash", "money", "dollar", "fund", "balance", "coin", "bank",
	"income", "profit", "networth", "worth", "budget", "wallet", "credit", "salar",
}

local function moneyRank(name)
	local n = flat(name)
	if n == "cash" or n == "money" then return 1 end
	for i, w in ipairs(MONEY_WORDS) do
		if n:find(w, 1, true) then return i + 1 end
	end
	return nil
end

local M = { entry = nil, base = nil, target = nil, lockOn = false, list = {} }
TY.money = M

local function pathOf(inst, name)
	local parts = { tostring(name) }
	local node = inst
	for _ = 1, 3 do
		if not node or node == LP or node == workspace or node:IsA("DataModel") then break end
		node = node.Parent
		if not node or node == LP or node == workspace or node:IsA("DataModel") then break end
		table.insert(parts, 1, node.Name)
	end
	return table.concat(parts, ".")
end

function M.read(e)
	e = e or M.entry
	if not e then return nil end
	if e.kind == "attr" then
		local ok, v = pcall(e.inst.GetAttribute, e.inst, e.name)
		return ok and v or nil
	end
	local ok, v = pcall(function() return e.inst.Value end)
	return ok and v or nil
end

function M.where(e)
	e = e or M.entry
	if not e then return "not found" end
	return pathOf(e.inst, e.name) .. (e.kind == "attr" and " · attribute" or " · value")
end

-- wide, budgeted sweep. Returns every numeric candidate it met: money-named ones
-- first, then the rest, so a number the game named "Total" is still reachable.
function M.gather()
	local named, others, seen = {}, {}, {}
	local budget = { n = 4000 }

	local function rankOf(name) return moneyRank(name) end

	local function consider(inst, kind, name, value)
		if type(value) ~= "number" then return end
		local key = tostring(inst) .. "|" .. tostring(name) .. kind
		if seen[key] then return end
		seen[key] = true
		local entry = { inst = inst, kind = kind, name = name, value = value, rank = rankOf(name) }
		if entry.rank then
			named[#named + 1] = entry
		elseif #others < 60 then
			others[#others + 1] = entry
		end
	end

	local function scan(inst, depth)
		budget.n -= 1
		if budget.n <= 0 or not inst then return end
		local okA, a = pcall(inst.GetAttributes, inst)
		if okA and type(a) == "table" then
			for k, v in pairs(a) do consider(inst, "attr", k, v) end
		end
		if depth <= 0 then return end
		local okK, kids = pcall(function() return inst:GetChildren() end)
		if not okK then return end
		for _, child in ipairs(kids) do
			budget.n -= 1
			if budget.n <= 0 then return end
			if child:IsA("NumberValue") or child:IsA("IntValue") then
				local okV, v = pcall(function() return child.Value end)
				consider(child, "value", child.Name, okV and v or nil)
			elseif child:IsA("Model") or child:IsA("Folder") or child:IsA("Configuration") then
				scan(child, depth - 1)
			end
		end
	end

	scan(LP, 3)
	scan(LP.Character, 1)
	scan(workspace, 3)
	scan(game:GetService("ReplicatedStorage"), 2)

	table.sort(named, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		return tostring(a.name) < tostring(b.name)
	end)
	table.sort(others, function(a, b) return tostring(a.name) < tostring(b.name) end)

	local out = {}
	for _, e in ipairs(named) do out[#out + 1] = e end
	for _, e in ipairs(others) do out[#out + 1] = e end
	M.list = out
	return out
end

function M.find()
	local all = M.gather()
	local best = nil
	for _, e in ipairs(all) do
		if e.rank then best = e; break end
	end
	M.entry = best
	M.base = best and best.value or nil
	return best
end

-- bind one of the offered candidates by hand. The value in the box follows, so a
-- manual choice behaves exactly like an auto-detected one afterwards.
function M.bind(e)
	if not e then return false end
	M.entry = e
	M.base = e.value
	return true
end

-- write, then read back. Tycoons usually reconcile money on the server, so a
-- value that reads back is not automatically a value that stays: the page shows
-- the difference and the lock is what closes it, one repeat at a time.
function M.set(n)
	if not M.entry then M.find() end
	local e = M.entry
	if not e then return false, "no money value on this player" end
	local v = math.floor(tonumber(n) or -1)
	if v < 0 then return false, "not a number" end
	local ok
	if e.kind == "attr" then
		ok = pcall(e.inst.SetAttribute, e.inst, e.name, v)
	else
		ok = pcall(function() e.inst.Value = v end)
	end
	if not ok then return false, "the game refused the write" end
	local now = M.read(e)
	if type(now) == "number" then e.value = now end
	if type(now) == "number" and now ~= v then
		return false, "server-owned · reads back as " .. tostring(math.floor(now))
	end
	return true
end

function M.reset()
	if M.base == nil then return false, "nothing mapped yet" end
	return M.set(M.base)
end

-- The lock is a small repeat, not a hook: every 0.35s, if the game has moved the
-- number, put it back. That survives a server reconcile without pretending the
-- write was ours to keep.
function M.lock(on, value)
	M.lockOn = on and true or false
	if on then M.target = math.floor(tonumber(value) or tonumber(M.target) or 0) end
	if M.conn then M.conn:Disconnect(); M.conn = nil end
	if not on then return true end
	if not M.entry then M.find() end
	if not M.entry then
		M.lockOn = false
		return false, "no money value to lock"
	end
	task.spawn(function()
		while M.lockOn do
			local now = M.read()
			if type(now) == "number" and now ~= M.target then
				pcall(function() M.set(M.target) end)
			end
			task.wait(0.35)
		end
	end)
	return true
end

-- thunderstorms --------------------------------------------------------------
-- The storm that eats cables and towers is a state the game holds somewhere, and
-- a client can only argue with its own copy of it. So: find the switches (a
-- weather value, a storm counter, a thunder chance), pin them to calm, and switch
-- off the effects that make the storm visible - each one saved and restorable, so
-- turning this off puts the game back rather than leaving it halfway edited.
local STORM_WORDS = { "thunder", "lightning", "storm", "weather", "rain", "hail", "wind" }

local CALM_STRINGS = { "clear", "sunny", "none", "calm", "no storm", "nostorm" }

local S = { on = false, controls = {}, soft = {}, adds = nil, killed = 0 }
TY.storm = S

local function stormMatch(name)
	local n = flat(name)
	for _, w in ipairs(STORM_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	return false
end

local function calmValue(current, name)
	if type(current) == "boolean" then return false end
	if type(current) == "number" then return 0 end
	if type(current) == "string" then
		-- a string weather state: if the game is already calm, leave the spelling
		-- alone; otherwise "Clear" is the value every weather enum here spells first
		for _, c in ipairs(CALM_STRINGS) do
			if flat(current):find(c, 1, true) then return current end
		end
		return "Clear"
	end
	return nil
end

-- the controls: value objects and attributes whose name says weather
function S.find()
	local out, seen = {}, {}

	local function consider(inst, kind, name)
		if not stormMatch(name) then return end
		local key = tostring(inst) .. "|" .. tostring(name) .. "|" .. kind
		if seen[key] then return end
		local v
		if kind == "attr" then
			local ok, got = pcall(inst.GetAttribute, inst, name)
			v = ok and got or nil
		else
			local ok, got = pcall(function() return inst.Value end)
			v = ok and got or nil
		end
		if type(v) ~= "number" and type(v) ~= "string" and type(v) ~= "boolean" then return end
		seen[key] = true
		out[#out + 1] = { inst = inst, kind = kind, name = name, value = v }
	end

	local function scanAttrs(inst)
		local ok, a = pcall(inst.GetAttributes, inst)
		if not (ok and type(a) == "table") then return end
		for k in pairs(a) do consider(inst, "attr", k) end
	end

	local function scanValues(inst, depth)
		scanAttrs(inst)
		depth = depth or 1
		if depth <= 0 then return end
		local ok, kids = pcall(function() return inst:GetChildren() end)
		if not ok then return end
		for _, child in ipairs(kids) do
			if child:IsA("NumberValue") or child:IsA("IntValue") or child:IsA("StringValue") or child:IsA("BoolValue") then
				consider(child, "value", child.Name)
			elseif child:IsA("Folder") or child:IsA("Configuration") then
				scanValues(child, depth - 1)
			end
		end
	end

	scanValues(game:GetService("Lighting"), 2)
	scanValues(LP, 2)
	scanValues(workspace, 1)
	local rs = game:GetService("ReplicatedStorage")
	scanValues(rs, 2)

	S.controls = out
	return out
end

-- write calm into every control that is not already calm
function S.apply()
	local n = 0
	for _, e in ipairs(S.controls) do
		local now
		if e.kind == "attr" then
			local ok, got = pcall(e.inst.GetAttribute, e.inst, e.name)
			now = ok and got or nil
		else
			local ok, got = pcall(function() return e.inst.Value end)
			now = ok and got or nil
		end
		if now ~= nil then
			local want = calmValue(now, e.name)
			if want ~= nil and want ~= now then
				local ok
				if e.kind == "attr" then
					ok = pcall(e.inst.SetAttribute, e.inst, e.name, want)
				else
					ok = pcall(function() e.inst.Value = want end)
				end
				if ok then
					n += 1
					e.value = want
				end
			end
		end
	end
	return n
end

-- Effects, not models: a lightning flash is a ParticleEmitter, a thunderclap is a
-- Sound. Those are safe to switch off and safe to switch back on. Anything else
-- named like a storm is left alone - destroying a game's own model is how a
-- script breaks a tycoon it was meant to help.
local function softTarget(inst)
	if inst:IsA("ParticleEmitter") or inst:IsA("Sound") or inst:IsA("Trail") or inst:IsA("Beam") then
		return "Enabled", false
	end
	if inst:IsA("PointLight") or inst:IsA("SpotLight") or inst:IsA("SurfaceLight") then
		return "Enabled", false
	end
	return nil
end

local function softOff(inst)
	local prop, quiet = softTarget(inst)
	if not prop then return false end
	for _, saved in ipairs(S.soft) do
		if saved.inst == inst then return false end
	end
	local ok, old = pcall(function() return inst[prop] end)
	if not (ok and old ~= nil) then return false end
	local wrote = pcall(function() inst[prop] = quiet end)
	if not wrote then return false end
	S.soft[#S.soft + 1] = { inst = inst, prop = prop, old = old }
	S.killed += 1
	return true
end

function S.sweep()
	if not S.on then return 0 end
	local n = 0
	local budget = 4000
	for _, inst in ipairs(workspace:GetDescendants()) do
		budget -= 1
		if budget <= 0 then break end
		if stormMatch(inst.Name) and softOff(inst) then n += 1 end
	end
	return n
end

function S.restore()
	for _, saved in ipairs(S.soft) do
		pcall(function() saved.inst[saved.prop] = saved.old end)
	end
	S.soft = {}
end

function S.set(on)
	on = on and true or false
	if on == S.on then return true end
	S.on = on
	if on then
		S.find()
		S.apply()
		S.sweep()
		if not S.adds then
			S.adds = workspace.DescendantAdded:Connect(function(inst)
				if not S.on then return end
				task.defer(function()
					if S.on and inst.Parent and stormMatch(inst.Name) then softOff(inst) end
				end)
			end)
		end
		-- the pin is a repeat for the same reason the money lock is: the game will
		-- set its own weather again, and a one-shot write is a lie by the next tick
		S.gen = (S.gen or 0) + 1
		local gen = S.gen
		task.spawn(function()
			while S.on and S.gen == gen do
				task.wait(1)
				if not S.on or S.gen ~= gen then break end
				pcall(S.apply)
			end
		end)
	else
		if S.adds then S.adds:Disconnect(); S.adds = nil end
		S.restore()
	end
	return true
end

function S.status()
	if not S.on then return "off" end
	return string.format("active · %d control%s · %d effect%s off",
		#S.controls, #S.controls == 1 and "" or "s",
		#S.soft, #S.soft == 1 and "" or "s")
end

onCleanup(function()
	M.lockOn = false
	S.on = false
	if S.adds then S.adds:Disconnect(); S.adds = nil end
	pcall(S.restore)
end)
