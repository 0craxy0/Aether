-- PARTIAL: written from the readable part of the original file only.
-- Everything after `toggle(sSA4` (the SA Hooks section, Kill aura page and the rest of Combat) is missing.
local A = ...
local makePage, makeConfig, gear = A.makePage, A.makeConfig, A.gear
local slider, toggle, dropdown = A.slider, A.toggle, A.dropdown
local Aim, SA = A.Aim, A.SA

local pCombat = makePage("Combat", 4)
local cfgAim = makeConfig("Aimbot")
local sMods = pCombat.section("Modules", 1)
local sAim = cfgAim.section("Targeting", 1)
local aimToggle = toggle(sMods, "Aimbot", false, function(v)
	if v then Aim.start() else Aim.stop() end
end)
gear(aimToggle, cfgAim)
dropdown(sAim, "Aim key", { "Right Mouse", "Left Mouse", "Always", "E", "Q", "LeftShift", "LeftAlt" }, "Right Mouse", function(v) Aim.s.aimKey = v end)
dropdown(sAim, "Aim part", { "Head", "Torso", "Closest", "Random" }, "Head", function(v) Aim.s.part = v end)
dropdown(sAim, "Aim priority", { "Cursor", "Distance", "Lowest health" }, "Cursor", function(v) Aim.s.priority = v end)
dropdown(sAim, "Aim method", { "Camera", "Mouse" }, "Camera", function(v) Aim.s.method = v end)

local sAim2 = cfgAim.section("Tuning", 2)
slider(sAim2, "Aim FOV", 20, 800, 150, function(v) Aim.s.fov = v end)
slider(sAim2, "Aim smoothing", 0, 95, 30, function(v) Aim.s.smooth = v end)
slider(sAim2, "Aim prediction", 0, 300, 0, function(v) Aim.s.prediction = v end)
slider(sAim2, "Aim jitter", 0, 10, 0, function(v) Aim.s.jitter = v end)
slider(sAim2, "Aim max distance", 50, 5000, 1500, function(v) Aim.s.maxDist = v end)

local sAim3 = cfgAim.section("Checks", 3)
toggle(sAim3, "Aim wall check", true, function(v) Aim.s.wallCheck = v end)
toggle(sAim3, "Aim team check", true, function(v) Aim.s.teamCheck = v end)
toggle(sAim3, "Aim forcefield check", true, function(v) Aim.s.ffCheck = v end)
toggle(sAim3, "Aim sticky target", false, function(v) Aim.s.sticky = v end)

local sAim4 = cfgAim.section("Visuals", 4)
toggle(sAim4, "Aim show FOV circle", true, function(v) Aim.s.showFov = v end)
toggle(sAim4, "Aim fill FOV circle", false, function(v) Aim.s.fovFilled = v end)
toggle(sAim4, "Aim snapline", true, function(v) Aim.s.snapline = v end)
toggle(sAim4, "Aim target info", true, function(v) Aim.s.targetInfo = v end)

local sAim5 = cfgAim.section("Triggerbot", 5)
toggle(sAim5, "Triggerbot", false, function(v) Aim.s.trigger = v end)
slider(sAim5, "Trigger delay (ms)", 0, 500, 80, function(v) Aim.s.triggerDelay = v end)

-- Silent aim --------------------------------------------------
local saToggle
local cfgSA = makeConfig("Silent aim")
local sSA = cfgSA.section("Targeting", 1)
saToggle = toggle(sMods, "Silent aim", false, function(v)
	if v then
		if not SA.start() then task.defer(function() saToggle.set(false, true) end) end
	else
		SA.stop()
	end
end)
gear(saToggle, cfgSA)
dropdown(sSA, "SA key", { "Always", "Right Mouse", "Left Mouse", "E", "Q", "LeftShift", "LeftAlt" }, "Always", function(v) SA.s.key = v end)
dropdown(sSA, "SA hit part", { "Head", "Torso", "Closest", "Random", "Mixed" }, "Head", function(v) SA.s.part = v end)
dropdown(sSA, "SA priority", { "Cursor", "Distance", "Lowest health" }, "Cursor", function(v) SA.s.priority = v end)
dropdown(sSA, "SA FOV origin", { "Cursor", "Center" }, "Cursor", function(v) SA.s.fovOrigin = v end)

local sSA2 = cfgSA.section("Tuning", 2)
slider(sSA2, "SA FOV", 20, 800, 180, function(v) SA.s.fov = v end)
slider(sSA2, "SA hit chance %", 0, 100, 100, function(v) SA.s.hitChance = v end)
slider(sSA2, "SA headshot chance %", 0, 100, 60, function(v) SA.s.headChance = v end)
slider(sSA2, "SA spread (studs)", 0, 5, 0, function(v) SA.s.spread = v end)
slider(sSA2, "SA prediction (ms)", 0, 300, 0, function(v) SA.s.prediction = v end)
slider(sSA2, "SA max distance", 50, 5000, 1500, function(v) SA.s.maxDist = v end)
slider(sSA2, "SA min target health", 0, 100, 0, function(v) SA.s.minHealth = v end)

local sSA3 = cfgSA.section("Checks", 3)
toggle(sSA3, "SA wall check", true, function(v) SA.s.wallCheck = v end)
toggle(sSA3, "SA team check", true, function(v) SA.s.teamCheck = v end)
toggle(sSA3, "SA forcefield check", true, function(v) SA.s.ffCheck = v end)
toggle(sSA3, "SA skip friends", false, function(v) SA.s.friendCheck = v end)
toggle(sSA3, "SA sticky target", false, function(v) SA.s.sticky = v end)

-- MISSING from here: sSA4 "Hooks" section onward (see header note)

