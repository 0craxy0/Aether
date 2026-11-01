local A = ...
local makePage, slider, toggle = A.makePage, A.slider, A.toggle
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

