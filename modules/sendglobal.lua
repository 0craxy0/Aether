local A = ...
local notify, onCleanup = A.notify, A.onCleanup
local LP = A.LP
local charParts = A.charParts

-- Send a Global Message: cash for touching a finish pad -----------------------
-- The game pays out when the character touches Map.Obbies.<tier>.WinPad, and
-- then teleports it to that tier's ObbySpawnPoint. Tiers unlock in order and a
-- pad you have not unlocked bounces you back to the previous tier's start, so
-- the farm only ever stands on a tier it has seen pay.
--
-- Measured on a live run (tools/padlog.lua, 2026-11-08):
--
--   tier        win pad (centre)          pays   sends you to
--   Easy        38.1, 878.2, -355.8       100    Easy spawn
--   Medium      86.3, 878.2, -395.0       200    Medium spawn
--   Hard       137.3, 876.3, -472.9       350    Hard spawn
--   Nightmare  183.4, 876.2, -550.5       550    Nightmare spawn
--   Insane     235.3, 937.3, -447.1       750    Insane spawn
--
-- The pads are looked up by instance every time (Map.Obbies.<tier>.WinPad), not
-- by those coordinates: a part found by name cannot drift when the map is
-- updated, and the numbers above are only here so a mismatch is obvious.
--
-- Cash lives in leaderstats.Cash; SG.cash() reads any numeric leaderstat or
-- player attribute whose name looks like a currency, so a rename does not break
-- the payout check.
--
-- Every tier has a cooldown between payouts, and it is waited out rather than
-- attempted around: a refusal on a cooling pad is a cooldown, not a failure, so
-- it must not count toward the miss limit that stops the farm. readyAt plus
-- SG.ready() is the whole mechanism - no attempt is sent at a pad that is known
-- to be cooling.
--
--   tier        pays   cooldown   pays per second (cooldown + ~0.9s overhead)
--   Easy         100     2s         ~34
--   Medium       200     3s         ~51
--   Hard         350     5s         ~59
--   Nightmare    550     8s         ~62
--   Insane       750    10s         ~69
--
-- Insane is still the best rate even with the longest cooldown, which is why
-- Auto settles on it; the ladder above is what makes that true rather than
-- assumed. Cooldowns are per tier, not per player, so nothing here needs the
-- player to swap servers between payouts.

local SG = {
	tiers = { "Easy", "Medium", "Hard", "Nightmare", "Insane" },
	pays = { Easy = 100, Medium = 200, Hard = 350, Nightmare = 550, Insane = 750 },
	-- seconds a tier refuses to pay again after it has paid (measured in game)
	cooldowns = { Easy = 2, Medium = 3, Hard = 5, Nightmare = 8, Insane = 10 },
	pad = 0,           -- extra seconds added to every cooldown, if the server is stricter

	tier = "Auto",     -- what to farm; "Auto" uses the highest tier seen paying
	interval = 0.9,    -- seconds between attempts
	lift = 2,          -- studs above the pad centre to place the character
	on = false,
	attempts = 0,
	earned = 0,
	last = nil,        -- human-readable result of the last attempt
	unlocked = nil,    -- highest tier index known to pay (1..5), nil = unknown
	readyAt = {},      -- tier -> os.clock() it is payable again
	pads = {},
	padsReady = false,
	cashPath = nil,
}
A.SG = SG

-- cooldown -------------------------------------------------------------------

-- What a tier's cooldown is, including the user's padding. One accessor so the
-- farm, detect() and the page can never disagree about it.
function SG.coolFor(tier)
	return (SG.cooldowns[tier] or 0) + (SG.pad or 0)
end

function SG.ready(tier)
	local at = SG.readyAt[tier]
	if not at then return 0 end
	local left = at - os.clock()
	if left <= 0 then
		SG.readyAt[tier] = nil
		return 0
	end
	return left
end

-- pads -----------------------------------------------------------------------

local function obbiesRoot()
	local map = workspace:FindFirstChild("Map")
	return map and map:FindFirstChild("Obbies") or nil
end

-- The pad for one tier, by instance. Falls back to any part called WinPad whose
-- ancestor carries the tier's name, which covers a map that stops nesting the
-- obby directly under Obbies.
local function findPad(root, tier, scan)
	-- No Obbies folder yet means the map has not replicated: answering "not
	-- found" is cheaper than five full descendant scans during the load, and
	-- SG.resolve() is called again by start()/Rescan once it is there.
	if not root then return nil end
	local model = root:FindFirstChild(tier)
	if model then
		local found = model:FindFirstChild("WinPad", true)
		if found and found:IsA("BasePart") then return found end
	end
	for _, d in ipairs(scan()) do
		if d:IsA("BasePart") and d.Name == "WinPad" then
			local node, hit = d.Parent, false
			for _ = 1, 5 do
				if not node then break end
				if node.Name == tier then hit = true; break end
				node = node.Parent
			end
			if hit then return d end
		end
	end
	return nil
end

function SG.resolve()
	local root = obbiesRoot()
	local out, ready = {}, false
	-- One descendant scan at most per resolve, shared by every tier that needed
	-- the fallback: five separate GetDescendants() on a big map is a visible
	-- hitch, and the direct Map.Obbies.<tier>.WinPad path usually means none.
	local cached
	local function scan()
		if not cached then cached = workspace:GetDescendants() end
		return cached
	end
	for i, tier in ipairs(SG.tiers) do
		local pad = findPad(root, tier, scan)
		out[i] = { tier = tier, part = pad, pos = pad and pad.Position or nil }
		if pad then ready = true end
	end
	SG.pads, SG.padsReady = out, ready
	return out
end

function SG.ensure()
	if SG.padsReady then return SG.pads end
	return SG.resolve()
end

local function padFor(tier)
	SG.ensure()
	for _, p in ipairs(SG.pads) do
		if p.tier == tier then return p end
	end
	return nil
end

-- cash -----------------------------------------------------------------------

local CASH_PATTERN = "cash|coin|money|token|credit|balance"

function SG.cash()
	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") and type(v.Value) == "number" and v.Name:lower():find(CASH_PATTERN) then
				SG.cashPath = "leaderstats." .. v.Name
				return v.Value
			end
		end
	end
	local ok, attrs = pcall(function() return LP:GetAttributes() end)
	if ok and type(attrs) == "table" then
		for name, value in pairs(attrs) do
			if type(value) == "number" and name:lower():find(CASH_PATTERN) then
				SG.cashPath = "@" .. name
				return value
			end
		end
	end
	return nil
end

-- touch ----------------------------------------------------------------------

local function stand(pos, lift)
	local _, _, root = charParts()
	if not root then return false, "no character" end
	root.CFrame = CFrame.new(pos + Vector3.new(0, lift or SG.lift, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- One attempt: stand on the pad, then watch the counter. Returns paid, delta,
-- reason. A locked pad simply never pays, which is what detect() reads.
function SG.tryTier(tier, timeout)
	local entry = padFor(tier)
	if not entry then return false, 0, "unknown tier" end
	if not entry.pos then return false, 0, "WinPad not found" end
	local cooling = SG.ready(tier)
	if cooling > 0 then return false, 0, string.format("cooling %.1fs", cooling) end

	local before = SG.cash()
	local ok, why = stand(entry.pos)
	if not ok then return false, 0, why end

	local deadline = os.clock() + (timeout or 2)
	local delta = 0
	while os.clock() < deadline do
		task.wait(0.05)
		local now = SG.cash()
		if before and now and now > before then
			delta = now - before
			break
		end
	end
	if delta > 0 then return true, delta, nil end
	return false, 0, "no payout"
end

-- Detect: touch each pad once from Easy up. The highest one that pays is the
-- highest unlocked tier, which is also the one worth farming.
function SG.detect()
	SG.resolve()
	local best, results = nil, {}
	for i, tier in ipairs(SG.tiers) do
		-- A cooling pad reads as "not unlocked", which is the one wrong answer
		-- detect() must not give, so its cooldown is waited out first.
		local cooling = SG.ready(tier)
		if cooling > 0 then task.wait(cooling + 0.05) end
		local ok, delta = SG.tryTier(tier, 2)
		results[#results + 1] = { tier = tier, ok = ok, delta = delta }
		if ok then
			best = i
			SG.readyAt[tier] = os.clock() + SG.coolFor(tier)
		end
		task.wait(SG.interval)
	end
	SG.unlocked = best
	SG.last = best and ("unlocked: " .. SG.tiers[best]) or "nothing paid · are you in the game?"
	return best, results
end

-- farm -----------------------------------------------------------------------

local farmThread

function SG.start()
	if SG.on then return end
	SG.on = true
	SG.attempts, SG.earned = 0, 0
	farmThread = task.spawn(function()
		-- A config can switch this on before the map has replicated, so the loop
		-- waits for the pads instead of refusing at load and leaving the toggle on.
		local waited = 0
		while SG.on and not SG.padsReady and waited < 15 do
			SG.resolve()
			if SG.padsReady then break end
			waited += 1
			task.wait(1)
		end
		if not SG.on then return end
		if not SG.padsReady then
			SG.on = false
			notify("Send a Global Message", "no WinPad found - are you in the game?", "bad")
			return
		end

		if SG.tier == "Auto" and not SG.unlocked then
			notify("Cash farm", "detecting the highest unlocked tier first", "good")
			pcall(SG.detect)
		end

		local misses = 0
		while SG.on do
			local tier = SG.tier
			if tier == "Auto" then
				tier = SG.unlocked and SG.tiers[SG.unlocked] or SG.tiers[1]
			end

			-- Cooling is not a failure, and it must not spend an attempt: sleep it
			-- out in slices so the switch still turns off promptly.
			local cooling = SG.ready(tier)
			if cooling > 0 then
				SG.last = string.format("%s · cooling %.1fs", tier, cooling)
				task.wait(math.min(cooling, 0.5))
				continue
			end

			local ok, delta = SG.tryTier(tier, 2)
			SG.attempts += 1
			if ok then
				misses = 0
				SG.earned += delta
				SG.readyAt[tier] = os.clock() + SG.coolFor(tier)
				SG.last = string.format("%s  +%d", tier, delta)
			else
				misses += 1
				SG.last = tier .. " · no payout"
				-- A pad that refused is more likely cooling than broken. Honour the
				-- cooldown so the retry comes at the rate the game allows instead of
				-- three fast failures that stop the farm.
				if SG.coolFor(tier) > 0 then
					SG.readyAt[tier] = os.clock() + SG.coolFor(tier)
				end
				if misses >= 3 then
					-- three quiet attempts: the pad moved, the game stopped paying,
					-- or the tier is locked. Stop rather than hammer it forever.
					SG.on = false
					notify("Cash farm", "3 attempts paid nothing · stopped", "bad")
					break
				end
			end
			task.wait(SG.interval)
		end
		SG.on = false
	end)
end

function SG.stop()
	SG.on = false
	if farmThread then pcall(task.cancel, farmThread); farmThread = nil end
end
onCleanup(SG.stop)

SG.resolve()
