local A = ...
local makePage, slider, toggle, button = A.makePage, A.slider, A.toggle, A.button
local state, charParts = A.state, A.charParts

local pChar = makePage("Character", 1)
local sChar = pChar.section("Movement stats", 1)
slider(sChar, "WalkSpeed", 16, 500, 16, function(v)
	state.speed, state.speedActive = v, true
	local _, hum = charParts()
	if hum then hum.WalkSpeed = v end
end)
slider(sChar, "JumpPower", 50, 500, 50, function(v)
	state.jump, state.jumpActive = v, true
	local _, hum = charParts()
	if hum then
		hum.UseJumpPower = true -- games that use JumpHeight ignore JumpPower entirely
		hum.JumpPower = v
	end
end)

local sChar2 = pChar.section("Behaviour", 2)
toggle(sChar2, "Infinite jump", false, A.setInfJump)
toggle(sChar2, "Noclip", false, A.setNoclip)
toggle(sChar2, "Anti-AFK", true, A.setAntiAfk)
toggle(sChar2, "Anti-void", false, A.setAntiVoid)

-- protection: about other people's scripts, not yours --------------------------
-- The section exists only when the module behind it does. A page reaching for a
-- missing module used to raise here and take the whole load down with it, which
-- is the one failure a guard feature should never cause.
local guard = A.guard
if not guard then
	warn("[Aether] modules/guard.lua did not load - the Protection section is skipped")
else
	local sChar3 = pChar.section("Protection", 3)
	toggle(sChar3, "Anti-fling", false, function(v) guard.setFling(v) end)
	-- Off by default: it cannot tell an attacker from the game teleporting you
	-- after a win, and it will fight the second one.
	toggle(sChar3, "Anti-teleport", false, function(v) guard.setTeleport(v) end)
	button(sChar3, "Panic: reset and unload", "PANIC", function() guard.panic() end)
end

