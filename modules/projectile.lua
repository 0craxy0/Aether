local A = ...
local RunService, Players, onCleanup = A.RunService, A.Players, A.onCleanup

-- Projectile gravity counter --------------------------------------------------
-- Guns that fire a part instead of a ray drop as they fly, so a shot aimed at a
-- head lands at their feet. This cancels the gravity step on the part every
-- physics frame, which leaves the projectile travelling in a straight line.
--
-- It can only do that on parts this client simulates. A part the server owns
-- ignores local velocity writes, and Arsenal decides that per weapon; where the
-- server keeps ownership this is a silent no-op rather than a fix, which is why
-- the count of parts actually being held is worth watching in a test.
local P = {
	on = false,
	pct = 100,      -- share of gravity to cancel: 100 = straight line
	minSpeed = 40,  -- a part slower than this is scenery, not a shot
	maxTracked = 160,
	watched = {},
	count = 0,
	added = nil,
	step = nil,
}
A.projectile = P

function P.isCharacterPart(part)
	local inst = part
	while inst and inst ~= workspace do
		if inst:IsA("Model") and Players:GetPlayerFromCharacter(inst) then return true end
		inst = inst.Parent
	end
	return false
end

function P.track(part)
	if not P.on or P.count >= P.maxTracked or P.watched[part] then return end
	if part.Anchored or P.isCharacterPart(part) then return end
	P.watched[part] = true
	P.count += 1
end

local function forget(part)
	if P.watched[part] then
		P.watched[part] = nil
		P.count = math.max(P.count - 1, 0)
	end
end

function P.tick(dt)
	local rate = workspace.Gravity * (P.pct / 100) * dt
	for part in pairs(P.watched) do
		local v
		if part.Parent and not part.Anchored then
			local ok, vel = pcall(function() return part.AssemblyLinearVelocity end)
			if ok then v = vel end
		end
		if not v or v.Magnitude < P.minSpeed then
			forget(part)
		elseif rate > 0 then
			-- one gravity step added back; pcall because a part can be destroyed
			-- between the read and the write
			pcall(function()
				part.AssemblyLinearVelocity = Vector3.new(v.X, v.Y + rate, v.Z)
			end)
		end
	end
end

function P.set(on)
	on = on and true or false
	if on == P.on then return end
	P.on = on

	if not on then
		if P.added then P.added:Disconnect(); P.added = nil end
		if P.step then P.step:Disconnect(); P.step = nil end
		table.clear(P.watched)
		P.count = 0
		return
	end

	-- parts already in flight when the switch is thrown, so it starts working on
	-- the next shot rather than only on projectiles spawned afterwards
	local budget = P.maxTracked
	for _, d in ipairs(workspace:GetDescendants()) do
		if budget <= 0 then break end
		if d:IsA("BasePart") and not d.Anchored then
			local ok, v = pcall(function() return d.AssemblyLinearVelocity end)
			if ok and v.Magnitude >= P.minSpeed then
				P.track(d)
				budget -= 1
			end
		end
	end

	P.added = workspace.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then P.track(d) end
	end)
	P.step = RunService.Stepped:Connect(function(_, dt) P.tick(dt) end)
end

onCleanup(function() P.set(false) end)
