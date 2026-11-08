local A = ...
local makePage, makeConfig, gear = A.makePage, A.makeConfig, A.gear
local slider, toggle, dropdown = A.slider, A.toggle, A.dropdown
local ESP = A.ESP

local pVis = makePage("Visuals", 3)
local sVis = pVis.section("World", 1)
toggle(sVis, "Fullbright", false, A.setFullbright)
toggle(sVis, "Remove fog", false, A.setNoFog)
toggle(sVis, "Disable particles", false, A.setNoParticles)
-- effects and environment lighting only: fog and shadows belong to the two rows
-- above, and two switches owning one property means the last one off wins
if A.world then
	toggle(sVis, "Low graphics", false, function(v) A.world.lowGraphics(v) end)
else
	warn("[Aether] modules/world.lua did not load - Low graphics is skipped")
end

local sVis2 = pVis.section("Camera", 2)
slider(sVis2, "Field of view", 40, 120, 70, function(v)
	local cam = workspace.CurrentCamera
	if cam then cam.FieldOfView = v end
end)

local cfgESP = makeConfig("Player ESP")
local sVis3 = pVis.section("Players", 3)
local espToggle = toggle(sVis3, "Player ESP", false, function(v)
	if v then ESP.start() else ESP.stop() end
end)
gear(espToggle, cfgESP)

local sEsp = cfgESP.section("Elements", 1)
local function espOpt(name, key, def)
	toggle(sEsp, "ESP " .. name, def, function(v) ESP.s[key] = v end)
end
espOpt("boxes", "box", true)
espOpt("box fill", "fill", false)
espOpt("names", "name", true)
espOpt("distance", "dist", true)
espOpt("held tool", "tool", false)
espOpt("health bar", "health", true)
espOpt("health number", "healthText", false)
espOpt("tracers", "tracer", true)
espOpt("skeleton", "skeleton", false)
espOpt("head dot", "headDot", false)
espOpt("off-screen arrows", "arrows", false)
espOpt("chams", "chams", false)

local sEsp2 = cfgESP.section("Style", 2)
dropdown(sEsp2, "ESP box style", { "Full", "Corner" }, "Full", function(v) ESP.s.boxStyle = v end)
dropdown(sEsp2, "ESP tracer origin", { "Bottom", "Center", "Top", "Mouse" }, "Bottom", function(v) ESP.s.tracerOrigin = v end)
dropdown(sEsp2, "ESP color mode", { "Accent", "Rainbow", "Team", "Visibility" }, "Accent", function(v) ESP.s.colorMode = v end)
slider(sEsp2, "ESP max distance", 100, 5000, 2000, function(v) ESP.s.maxDist = v end)
slider(sEsp2, "ESP text size", 10, 20, 13, function(v) ESP.s.textSize = v end)
toggle(sEsp2, "ESP team check", false, function(v) ESP.s.teamCheck = v end)

A.stage("4 character/movement/visuals pages done")

