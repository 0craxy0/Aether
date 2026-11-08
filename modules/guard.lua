local A = ...
local notify, onCleanup = A.notify, A.onCleanup
local LP, RunService = A.LP, A.RunService
local charParts = A.charParts

-- Guard -----------------------------------------------------------------------
-- Two protective switches and one panic. All three are about living in a public
-- server, where other people's scripts act on you:
--
--   anti-fling     another script launches you with a huge angular velocity.
--                  Cancelling the spin is the whole fix; nothing legitimate
--                  spins a character at 2500 rad/s.
--   anti-teleport  someone moves your root somewhere else. Off by default,
--                  because it cannot tell an attacker from the game itself - a
--                  game that teleports you after a win would be fought by it.
--                  Anything in this hub that moves you calls expect() first.
--   panic          reset the character and unload the hub in one press, for when
--                  a script has left you in a state you cannot walk out of.

local G = {
	fling = false,
	teleport = false,
	spinLimit = 2500,   -- rad/s before the spin is treated as a fling
	speedLimit = 400,   -- studs/s before linear velocity is capped
	jumpLimit = 60,     -- studs in one frame that count as someone else moving you
	ignoreUntil = 0,
	lastPos = nil,
	lastChar = nil,
	armedAt = 0,
}
A.guard = G

-- Anything in the hub that intentionally moves the player announces itself here,
-- so anti-teleport does not undo it.
function G.expect(seconds)
	G.ignoreUntil = math.max(G.ignoreUntil, os.clock() + (seconds or 1.5))
end

local function expecting()
	return os.clock() < G.ignoreUntil
end

-- One heartbeat for both switches: two loops over the same root is wasted work,
-- and they have to agree about what "the current root" is.
local conn = RunService.Heartbeat:Connect(function()
	if not (G.fling or G.teleport) then return end
	local _, hum, root = charParts()
	if not root or not hum then
		G.lastPos, G.lastChar = nil, nil
		return
	end

	if G.fling then
		local spin = root.AssemblyAngularVelocity
		if spin.Magnitude > G.spinLimit then
			root.AssemblyAngularVelocity = Vector3.zero
		end
		local vel = root.AssemblyLinearVelocity
		if vel.Magnitude > G.speedLimit then
			root.AssemblyLinearVelocity = vel.Unit * G.speedLimit
		end
	end

	if G.teleport then
		local p = root.Position
		if G.lastPos and G.lastChar == LP.Character and hum.Health > 0 and not expecting() then
			if (p - G.lastPos).Magnitude > G.jumpLimit then
				root.CFrame = CFrame.new(G.lastPos)
				root.AssemblyLinearVelocity = Vector3.zero
				G.lastPos = nil
				if G.onTeleportBlocked then pcall(G.onTeleportBlocked) end
				return
			end
		end
		G.lastPos, G.lastChar = p, LP.Character
	end
end)
onCleanup(function() conn:Disconnect() end)

-- The last known position is stale after a respawn; a fresh character starts
-- somewhere else legitimately.
local charConn = LP.CharacterAdded:Connect(function()
	G.lastPos, G.lastChar = nil, nil
end)
onCleanup(function() charConn:Disconnect() end)

function G.setFling(on)
	G.fling = on and true or false
end

function G.setTeleport(on)
	G.teleport = on and true or false
	G.lastPos, G.lastChar = nil, nil
	G.armedAt = os.clock()
end

function G.panic()
	local _, hum = charParts()
	if hum then pcall(function() hum.Health = 0 end) end
	-- Tear the hub down last: unloading first would leave the reset below running
	-- against a screen that no longer exists, which is only cosmetic but pointless.
	if type(A.unload) == "function" then pcall(A.unload) end
end
