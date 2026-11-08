local A = ...
local T, notify, onCleanup, mk_has = A.T, A.notify, A.onCleanup, A.has
local LP, Players, RunService, UserInputService = A.LP, A.Players, A.RunService, A.UserInputService
local screen, maskSet = A.screen, A.maskSet

local ESP = { active = false, conn = nil, objects = {}, chams = {} }
A.ESP = ESP

-- Per-player character cache. Everything below needs the same three parts of the
-- same character on every frame, and FindFirstChild walks a tree: caching them
-- against the model that owns them costs one comparison per frame instead.
local CACHE = {}

local function forget(plr)
	CACHE[plr] = nil
end

local function dropESP(plr)
	local set = ESP.objects[plr]
	if not set then return end
	for _, d in pairs(set) do pcall(function() d:Remove() end) end
	ESP.objects[plr] = nil
end
local dropConn = Players.PlayerRemoving:Connect(function(plr)
	dropESP(plr)
	forget(plr)
	local h = ESP.chams[plr]
	if h then
		pcall(function() h:Destroy() end)
		ESP.chams[plr] = nil
	end
end)
onCleanup(function() dropConn:Disconnect() end)

ESP.s = {
	box = true, boxStyle = "Full", fill = false,
	name = true, dist = true, tool = false,
	health = true, healthText = false,
	tracer = true, tracerOrigin = "Bottom",
	skeleton = false, headDot = false, arrows = false, chams = false,
	teamCheck = false, colorMode = "Accent",
	maxDist = 2000, textSize = 13,
}
local S = ESP.s

local R15_BONES = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local R6_BONES = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" },
	{ "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}
local MAX_BONES = #R15_BONES

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function killCham(plr)
	local h = ESP.chams[plr]
	if h then pcall(function() h:Destroy() end) end
	ESP.chams[plr] = nil
end

-- Rainbow used to call Color3.fromHSV on every player, every frame, and every
-- value it produced in one frame was the same one. One colour per frame now.
local rainbow, rainbowAt = nil, 0
local function frameColor()
	local now = tick()
	if not rainbow or now - rainbowAt >= 1 / 30 then
		rainbowAt, rainbow = now, Color3.fromHSV(now % 5 / 5, 1, 1)
	end
	return rainbow
end

local function espColor(plr, visible)
	local m = S.colorMode
	if m == "Rainbow" then return frameColor() end
	if m == "Team" then return plr.Team and plr.TeamColor.Color or T.accent end
	if m == "Visibility" then return visible and T.good or T.bad end
	return T.accent
end

local function mk(kind, props)
	local d = Drawing.new(kind)
	for k, v in pairs(props) do d[k] = v end
	return d
end

-- per-set bookkeeping, keyed by the set itself and collected with it
local flags = setmetatable({}, { __mode = "k" })
local function fl(set)
	local f = flags[set]
	if not f then
		f = { vis = true, txt = {}, sk = false }
		flags[set] = f
	end
	return f
end

local function newESPSet()
	local set = {
		fill = mk("Square", { Filled = true, Transparency = 0.15 }),
		boxOut = mk("Square", { Filled = false, Thickness = 3, Color = Color3.new(0, 0, 0) }),
		box = mk("Square", { Filled = false, Thickness = 1 }),
		name = mk("Text", { Center = true, Outline = true, OutlineColor = Color3.new(0, 0, 0), Font = 2, Color = Color3.new(1, 1, 1) }),
		info = mk("Text", { Center = true, Outline = true, OutlineColor = Color3.new(0, 0, 0), Font = 2, Color = Color3.fromRGB(200, 205, 212) }),
		hpBg = mk("Square", { Filled = true, Color = Color3.fromRGB(20, 20, 24), Transparency = 0.65 }),
		hp = mk("Square", { Filled = true }),
		hpText = mk("Text", { Center = true, Outline = true, OutlineColor = Color3.new(0, 0, 0), Font = 2, Color = Color3.new(1, 1, 1) }),
		tracer = mk("Line", { Thickness = 1 }),
		head = mk("Circle", { Filled = false, Thickness = 1, NumSides = 16 }),
		arrow = mk("Triangle", { Filled = true }),
	}
	-- No bookkeeping keys inside the set: modules/filter.lua's maskSet walks
	-- pairs(set) and reads .Visible on everything it finds, so a boolean stashed
	-- here would be indexed as a Drawing and raise. Per-set flags live beside it.
	flags[set] = { vis = true, txt = {}, sk = false }
	for i = 1, 8 do
		local ln = mk("Line", { Thickness = 1 })
		ln.Visible = false
		set["c" .. i] = ln
	end
	for i = 1, MAX_BONES do
		local ln = mk("Line", { Thickness = 1 })
		ln.Visible = false
		set["sk" .. i] = ln
	end
	return set
end

local DRAWABLES = {
	"fill", "boxOut", "box", "name", "info", "hpBg", "hp", "hpText", "tracer", "head", "arrow",
}

local function hide(set)
	local f = fl(set)
	if not f.vis then return end -- already dark; no reason to write 40 properties
	f.vis = false
	for _, k in ipairs(DRAWABLES) do set[k].Visible = false end
	for i = 1, 8 do set["c" .. i].Visible = false end
	for i = 1, MAX_BONES do set["sk" .. i].Visible = false end
end

local function show(set)
	fl(set).vis = true
end

function ESP.stop()
	if ESP.conn then ESP.conn:Disconnect(); ESP.conn = nil end
	-- Snapshot the keys first: dropESP clears the entry it is handed, and
	-- removing the current key while iterating a table with next is undefined.
	local players, chams = {}, {}
	for plr in pairs(ESP.objects) do players[#players + 1] = plr end
	for plr in pairs(ESP.chams) do chams[#chams + 1] = plr end
	for _, plr in ipairs(players) do dropESP(plr) end
	for _, plr in ipairs(chams) do killCham(plr) end
	CACHE = {}
	ESP.active = false
end

-- One character, resolved once per spawn. Returns nil when there is nothing
-- worth drawing, which is also the cheapest possible answer.
local function characterOf(plr)
	local c = plr.Character
	if not c then return nil end
	local e = CACHE[plr]
	if e and e.char == c then return e end
	local root = c:FindFirstChild("HumanoidRootPart")
	local hum = c:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return nil end
	e = { char = c, root = root, hum = hum, parts = {} }
	CACHE[plr] = e
	return e
end

local function partOf(e, name)
	local p = e.parts[name]
	if p and p.Parent == e.char then return p end
	p = e.char:FindFirstChild(name)
	e.parts[name] = p
	return p
end

function ESP.start()
	if not mk_has.drawing then return notify("ESP", "Drawing API unavailable", "bad") end
	if ESP.conn then return end
	ESP.active = true

	ESP.conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local camPos = cam.CFrame.Position
		local mouse = nil -- fetched only when the tracer actually comes from it
		local wantRay = S.colorMode == "Visibility"
		local maxD2 = S.maxDist * S.maxDist

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LP then continue end
			local e = characterOf(plr)
			local hidden = not e or e.hum.Health <= 0
			if not hidden and S.teamCheck and LP.Team ~= nil and plr.Team == LP.Team then
				hidden = true
			end

			local root = e and e.root
			local offset = root and (root.Position - camPos)
			-- squared first: the square root is only for the label, and only for
			-- a player who passed the range test
			local d2 = offset and offset:Dot(offset) or nil
			if not hidden and d2 and d2 > maxD2 then hidden = true end

			if hidden then
				local set = ESP.objects[plr]
				if set then hide(set) end
				killCham(plr)
				continue
			end

			local set = ESP.objects[plr]
			if not set then
				set = newESPSet()
				ESP.objects[plr] = set
			end
			show(set)
			local f = fl(set)

			local c, hum = e.char, e.hum
			local dist = math.sqrt(d2)

			local visible = false
			if wantRay then
				rayParams.FilterDescendantsInstances = { LP.Character, c }
				visible = workspace:Raycast(camPos, offset, rayParams) == nil
			end
			local col = espColor(plr, visible)

			-- chams
			if S.chams then
				local h = ESP.chams[plr]
				if not h then
					h = Instance.new("Highlight")
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.FillTransparency = 0.5
					h.OutlineColor = Color3.new(1, 1, 1)
					h.Parent = screen
					ESP.chams[plr] = h
				end
				h.Adornee = c
				h.FillColor = col
			elseif ESP.chams[plr] then
				killCham(plr)
			end

			local hs, hOn = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 1.6, 0))
			local fs, fOn = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

			if not hOn or not fOn or hs.Z < 0 or fs.Z < 0 then
				hide(set)
				if S.arrows then
					local rel = cam.CFrame:PointToObjectSpace(root.Position)
					local dir = Vector2.new(rel.X, rel.Z)
					if dir.Magnitude > 0 then
						dir = dir.Unit
						local pos = vp / 2 + dir * (math.min(vp.X, vp.Y) * 0.4)
						local perp = Vector2.new(-dir.Y, dir.X)
						set.arrow.PointA = pos + dir * 12
						set.arrow.PointB = pos - dir * 6 + perp * 8
						set.arrow.PointC = pos - dir * 6 - perp * 8
						set.arrow.Color = col
						-- the arrow is the one thing that survives an off-screen
						-- frame, so the set counts as lit for the next hide()
						f.vis = true
						set.arrow.Visible = true
						maskSet(set)
					end
				end
				continue
			end
			set.arrow.Visible = false

			local h = math.abs(fs.Y - hs.Y)
			local w = h * 0.52
			local x = math.min(hs.X, fs.X) - w / 2
			local y = math.min(hs.Y, fs.Y)
			local cx = x + w / 2

			-- box
			local full = S.box and S.boxStyle == "Full"
			local corners = S.box and S.boxStyle == "Corner"
			set.boxOut.Visible = full
			set.box.Visible = full
			if full then
				local tl = Vector2.new(x, y)
				local sz = Vector2.new(w, h)
				set.boxOut.Position = tl
				set.boxOut.Size = sz
				set.box.Position = tl
				set.box.Size = sz
				set.box.Color = col
			end

			-- corner brackets: eight constant segments, so the table is built once
			-- per frame only when they are actually on
			if corners then
				local cl, cv = w * 0.28, h * 0.2
				local x2, y2 = x + w, y + h
				local segs = {
					{ x, y, x + cl, y }, { x, y, x, y + cv },
					{ x2, y, x2 - cl, y }, { x2, y, x2, y + cv },
					{ x, y2, x + cl, y2 }, { x, y2, x, y2 - cv },
					{ x2, y2, x2 - cl, y2 }, { x2, y2, x2, y2 - cv },
				}
				for i = 1, 8 do
					local ln, sg = set["c" .. i], segs[i]
					ln.From = Vector2.new(sg[1], sg[2])
					ln.To = Vector2.new(sg[3], sg[4])
					ln.Color = col
					ln.Visible = true
				end
			else
				for i = 1, 8 do
					local ln = set["c" .. i]
					if ln.Visible then ln.Visible = false end
				end
			end
			set.fill.Visible = S.fill
			if S.fill then
				set.fill.Position = Vector2.new(x, y)
				set.fill.Size = Vector2.new(w, h)
				set.fill.Color = col
			end

			-- name
			set.name.Visible = S.name
			if S.name then
				set.name.Size = S.textSize
				set.name.Position = Vector2.new(cx, y - S.textSize - 3)
				local label = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
				if f.txt.name ~= label then
					f.txt.name = label
					set.name.Text = label
				end
			end

			-- info line: distance / tool
			local bitCount = 0
			local infoText
			if S.dist then
				bitCount = 1
				infoText = math.floor(dist) .. "m"
			end
			if S.tool then
				local tl = c:FindFirstChildOfClass("Tool")
				if tl then
					bitCount = bitCount + 1
					infoText = infoText and (infoText .. "  ·  " .. tl.Name) or tl.Name
				end
			end
			set.info.Visible = bitCount > 0
			if bitCount > 0 then
				set.info.Size = math.max(S.textSize - 2, 9)
				set.info.Position = Vector2.new(cx, y + h + 2)
				if f.txt.info ~= infoText then
					f.txt.info = infoText
					set.info.Text = infoText
				end
			end

			-- health
			local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			set.hpBg.Visible = S.health
			set.hp.Visible = S.health
			if S.health then
				set.hpBg.Position = Vector2.new(x - 5, y)
				set.hpBg.Size = Vector2.new(2, h)
				set.hp.Position = Vector2.new(x - 5, y + h * (1 - frac))
				set.hp.Size = Vector2.new(2, h * frac)
				set.hp.Color = frac > 0.5 and T.good or frac > 0.25 and T.warn or T.bad
			end
			set.hpText.Visible = S.healthText
			if S.healthText then
				set.hpText.Size = math.max(S.textSize - 3, 9)
				set.hpText.Position = Vector2.new(x - 16, math.clamp(y + h * (1 - frac) - 5, y, y + h - 10))
				local hpText = tostring(math.floor(hum.Health))
				if f.txt.hp ~= hpText then
					f.txt.hp = hpText
					set.hpText.Text = hpText
				end
			end

			-- tracer
			set.tracer.Visible = S.tracer
			if S.tracer then
				local o = S.tracerOrigin
				local from
				if o == "Center" then
					from = vp / 2
				elseif o == "Top" then
					from = Vector2.new(vp.X / 2, 0)
				elseif o == "Mouse" then
					mouse = mouse or UserInputService:GetMouseLocation()
					from = Vector2.new(mouse.X, mouse.Y)
				else
					from = Vector2.new(vp.X / 2, vp.Y)
				end
				set.tracer.From = from
				set.tracer.To = Vector2.new(cx, y + h)
				set.tracer.Color = col
			end

			-- head dot
			if S.headDot then
				local headPart = partOf(e, "Head")
				set.head.Visible = false
				if headPart then
					local p, on = cam:WorldToViewportPoint(headPart.Position)
					if on and p.Z > 0 then
						set.head.Visible = true
						set.head.Position = Vector2.new(p.X, p.Y)
						set.head.Radius = math.max(2, h / 12)
						set.head.Color = col
					end
				end
			elseif set.head.Visible then
				set.head.Visible = false
			end

			-- skeleton: 14 pairs is 28 FindFirstChild and 28 projections per
			-- player per frame, so it does not run at all unless it is on
			if S.skeleton then
				local bones = hum.RigType == Enum.HumanoidRigType.R15 and R15_BONES or R6_BONES
				for i = 1, MAX_BONES do
					local ln = set["sk" .. i]
					local pair = bones[i]
					local shown = false
					if pair then
						local a, b = partOf(e, pair[1]), partOf(e, pair[2])
						if a and b then
							local pa, oa = cam:WorldToViewportPoint(a.Position)
							local pb, ob = cam:WorldToViewportPoint(b.Position)
							if oa and ob and pa.Z > 0 and pb.Z > 0 then
								ln.From = Vector2.new(pa.X, pa.Y)
								ln.To = Vector2.new(pb.X, pb.Y)
								ln.Color = col
								shown = true
							end
						end
					end
					ln.Visible = shown
				end
			elseif f.sk then
				for i = 1, MAX_BONES do set["sk" .. i].Visible = false end
			end
			f.sk = S.skeleton

			maskSet(set)
		end
	end)
end
onCleanup(function() ESP.stop() end)
