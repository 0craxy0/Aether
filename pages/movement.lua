local A = ...
local makePage, makeConfig, gear = A.makePage, A.makeConfig, A.gear
local slider, toggle, button = A.slider, A.toggle, A.button
local fly, charParts, notify = A.fly, A.charParts, A.notify

local pMove = makePage("Movement", 2)
local cfgFly = makeConfig("Fly")
local sMove = pMove.section("Flight", 1)
local sFlyCfg = cfgFly.section("Flight", 1)
local flyToggle = toggle(sMove, "Fly", false, function(v)
	if v then fly.start() else fly.stop() end
end)
gear(flyToggle, cfgFly)
slider(sFlyCfg, "Fly speed", 10, 400, 55, function(v) fly.speed = v end)

local sMove2 = pMove.section("Teleport", 2)
button(sMove2, "Teleport to cursor", "GO", A.tpToCursor)
button(sMove2, "Freeze position", "FREEZE", function()
	local _, _, root = charParts()
	if root then
		root.Anchored = not root.Anchored
		notify("Freeze", root.Anchored and "anchored" or "released")
	end
end)
button(sMove2, "Reset character", "RESET", function()
	local _, hum = charParts()
	if hum then hum.Health = 0 end
end)

