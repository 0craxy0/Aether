-- Combat page: Aimbot, Silent aim, Kill aura.
-- Requires A.Aim, A.SA and A.KA from the modules loaded before it.
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

local sSA4 = cfgSA.section("Hooks", 4)
toggle(sSA4, "SA hook Raycast", true, function(v) SA.s.mRaycast = v end)
toggle(sSA4, "SA hook FindPartOnRay", true, function(v) SA.s.mFindPart = v end)
toggle(sSA4, "SA hook ScreenPointToRay", true, function(v) SA.s.mScreenRay = v end)
toggle(sSA4, "SA hook Mouse.Hit", true, function(v) SA.s.mMouse = v end)

local sSA5 = cfgSA.section("Visuals", 5)
toggle(sSA5, "SA show FOV circle", true, function(v) SA.s.showFov = v end)
toggle(sSA5, "SA fill FOV circle", false, function(v) SA.s.fovFilled = v end)
toggle(sSA5, "SA snapline", false, function(v) SA.s.snapline = v end)
toggle(sSA5, "SA target info", true, function(v) SA.s.targetInfo = v end)
toggle(sSA5, "SA target dot", true, function(v) SA.s.targetDot = v end)

-- Kill aura ---------------------------------------------------
local KA = A.KA
local cfgKA = makeConfig("Kill aura")
local sKA = cfgKA.section("Targeting", 1)
local kaToggle = toggle(sMods, "Kill aura", false, function(v)
	if v then KA.start() else KA.stop() end
end)
gear(kaToggle, cfgKA)
slider(sKA, "KA range", 3, 60, 15, function(v) KA.s.range = v end)
dropdown(sKA, "KA mode", { "Nearest", "Lowest health", "All in range" }, "Nearest", function(v) KA.s.mode = v end)
slider(sKA, "KA max targets", 1, 10, 3, function(v) KA.s.maxTargets = v end)
dropdown(sKA, "KA key", { "Always", "Right Mouse", "Left Mouse", "E", "Q", "LeftShift", "LeftAlt" }, "Always", function(v) KA.s.key = v end)
toggle(sKA, "KA sticky target", false, function(v) KA.s.sticky = v end)

local sKA2 = cfgKA.section("Attack", 2)
dropdown(sKA2, "KA method", { "Activate", "Touch", "Both" }, "Activate", function(v) KA.s.method = v end)
dropdown(sKA2, "KA hit part", { "HumanoidRootPart", "Head", "Torso", "All" }, "HumanoidRootPart", function(v) KA.s.hitPart = v end)
slider(sKA2, "KA delay (ms)", 0, 1000, 100, function(v) KA.s.delay = v end)
slider(sKA2, "KA swings per hit", 1, 10, 1, function(v) KA.s.swings = v end)
toggle(sKA2, "KA auto equip tool", true, function(v) KA.s.autoEquip = v end)
slider(sKA2, "KA stop below health %", 0, 100, 0, function(v) KA.s.stopHealth = v end)

local sKA3 = cfgKA.section("Positioning", 3)
toggle(sKA3, "KA face target", true, function(v) KA.s.faceTarget = v end)
toggle(sKA3, "KA stay behind target", false, function(v) KA.s.behind = v end)
slider(sKA3, "KA behind distance", 1, 15, 3, function(v) KA.s.behindDist = v end)

local sKA4 = cfgKA.section("Reach", 4)
toggle(sKA4, "KA extend reach", false, function(v) KA.setReach(v) end)
slider(sKA4, "KA reach size", 2, 60, 12, function(v) KA.s.reachSize = v end)

local sKA5 = cfgKA.section("Checks", 5)
toggle(sKA5, "KA wall check", false, function(v) KA.s.wallCheck = v end)
toggle(sKA5, "KA team check", true, function(v) KA.s.teamCheck = v end)
toggle(sKA5, "KA forcefield check", true, function(v) KA.s.ffCheck = v end)
toggle(sKA5, "KA skip friends", false, function(v) KA.s.friendCheck = v end)
toggle(sKA5, "KA skip sitting", false, function(v) KA.s.skipSitting = v end)

local sKA6 = cfgKA.section("Visuals", 6)
toggle(sKA6, "KA show range ring", true, function(v) KA.s.showRing = v end)
toggle(sKA6, "KA highlight target", true, function(v) KA.s.highlight = v end)
toggle(sKA6, "KA kill notifications", false, function(v) KA.s.killNotify = v end)

-- Projectiles --------------------------------------------------
local P = A.projectile
local cfgProj = makeConfig("Projectiles")
local sProj = pCombat.section("Projectiles", 2)
local projToggle = toggle(sProj, "Counter projectile gravity", false, function(v) P.set(v) end)
gear(projToggle, cfgProj)

local sProj1 = cfgProj.section("Counter", 1)
slider(sProj1, "Counter strength %", 0, 100, 100, function(v) P.pct = v end)
slider(sProj1, "Min speed", 10, 200, 40, function(v) P.minSpeed = v end)
A.label({
	Text = "Adds one gravity step back to every projectile part each physics frame, so a shot flies where it was aimed instead of dropping. Only parts this client simulates can be corrected: anything the server keeps ownership of ignores local velocity and still falls.",
	TextColor3 = A.T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 64), Parent = sProj1,
})

A.stage("5 combat page done")
