local A = ...
local T, notify, onCleanup, mk_has = A.T, A.notify, A.onCleanup, A.has
local LP, Players, RunService, UserInputService = A.LP, A.Players, A.RunService, A.UserInputService
local screen, maskSet = A.screen, A.maskSet

local ESP = { active = false, conn = nil, objects = {}, chams = {} }
A.ESP = ESP

local function dropESP(plr)
	local set = ESP.objects[plr]
	if not set then return end
	for _, d in pairs(set) do pcall(function() d:Remove() end) end
	ESP.objects[plr] = nil
end
Players.PlayerRemoving:Connect(dropESP)

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
Players.PlayerRemoving:Connect(killCham)

local function espColor(plr, visible)
	local m = S.colorMode
	if m == "Rainbow" then return Color3.fromHSV(tick() % 5 / 5, 1, 1) end
	if m == "Team" then return plr.Team and plr.TeamColor.Color or T.accent end
	if m == "Visibility" then return visible and T.good or T.bad end
	return T.accent
end

local function mk(kind, props)
	local d = Drawing.new(kind)
	for k, v in pairs(props) do d[k] = v end
	return d
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
	for i = 1, 8 do set["c" .. i] = mk("Line", { Thickness = 1 }) end
	for i = 1, MAX_BONES do set["sk" .. i] = mk("Line", { Thickness = 1 }) end
	return set
end

function ESP.stop()
	if ESP.conn then ESP.conn:Disconnect(); ESP.conn = nil end
	for plr in pairs(ESP.objects) do dropESP(plr) end
	for plr in pairs(ESP.chams) do killCham(plr) end
	ESP.active = false
end

function ESP.start()
	if not mk_has.drawing then return notify("ESP", "Drawing API unavailable", "bad") end
	if ESP.conn then return end
	ESP.active = true

	local function hide(set)
		for _, d in pairs(set) do d.Visible = false end
	end

	ESP.conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local mouse = UserInputService:GetMouseLocation()

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr == LP then continue end
			local set = ESP.objects[plr]
			if not set then
				set = newESPSet()
				ESP.objects[plr] = set
			end

			-- Phantom Forces note: plr.Character is not used there; a shared getChar helper is planned
			local c = plr.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local hum = c and c:FindFirstChildOfClass("Humanoid")

			if not root or not hum or hum.Health <= 0
				or (S.teamCheck and LP.Team ~= nil and plr.Team == LP.Team) then
				hide(set)
				killCham(plr)
				continue
			end

			local dist = (root.Position - cam.CFrame.Position).Magnitude
			if dist > S.maxDist then
				hide(set)
				killCham(plr)
				continue
			end

			local visible = false
			if S.colorMode == "Visibility" then
				rayParams.FilterDescendantsInstances = { LP.Character, c }
				visible = workspace:Raycast(cam.CFrame.Position, root.Position - cam.CFrame.Position, rayParams) == nil
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
			else
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
				set.boxOut.Position = Vector2.new(x, y)
				set.boxOut.Size = Vector2.new(w, h)
				set.box.Position = Vector2.new(x, y)
				set.box.Size = Vector2.new(w, h)
				set.box.Color = col
			end
			local cl, cv = w * 0.28, h * 0.2
			local segs = {
				{ x, y, x + cl, y }, { x, y, x, y + cv },
				{ x + w, y, x + w - cl, y }, { x + w, y, x + w, y + cv },
				{ x, y + h, x + cl, y + h }, { x, y + h, x, y + h - cv },
				{ x + w, y + h, x + w - cl, y + h }, { x + w, y + h, x + w, y + h - cv },
			}
			for i = 1, 8 do
				local ln = set["c" .. i]
				ln.Visible = corners
				if corners then
					local sg = segs[i]
					ln.From = Vector2.new(sg[1], sg[2])
					ln.To = Vector2.new(sg[3], sg[4])
					ln.Color = col
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
				set.name.Text = plr.DisplayName ~= plr.Name and (plr.DisplayName .. " (@" .. plr.Name .. ")") or plr.Name
			end

			-- info line: distance / tool
			local bits = {}
			if S.dist then bits[#bits + 1] = math.floor(dist) .. "m" end
			if S.tool then
				local tl = c:FindFirstChildOfClass("Tool")
				if tl then bits[#bits + 1] = tl.Name end
			end
			set.info.Visible = #bits > 0
			if #bits > 0 then
				set.info.Size = math.max(S.textSize - 2, 9)
				set.info.Position = Vector2.new(cx, y + h + 2)
				set.info.Text = table.concat(bits, "  ·  ")
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
				set.hp.Color = frac > 0.5 and T.good or frac > 0.25 and Color3.fromRGB(240, 190, 60) or T.bad
			end
			set.hpText.Visible = S.healthText
			if S.healthText then
				set.hpText.Size = math.max(S.textSize - 3, 9)
				set.hpText.Position = Vector2.new(x - 16, math.clamp(y + h * (1 - frac) - 5, y, y + h - 10))
				set.hpText.Text = tostring(math.floor(hum.Health))
			end

			-- tracer
			set.tracer.Visible = S.tracer
			if S.tracer then
				local o = S.tracerOrigin
				local from = Vector2.new(vp.X / 2, vp.Y)
				if o == "Center" then from = vp / 2
				elseif o == "Top" then from = Vector2.new(vp.X / 2, 0)
				elseif o == "Mouse" then from = Vector2.new(mouse.X, mouse.Y) end
				set.tracer.From = from
				set.tracer.To = Vector2.new(cx, y + h)
				set.tracer.Color = col
			end

			-- head dot
			local headPart = c:FindFirstChild("Head")
			set.head.Visible = false
			if S.headDot and headPart then
				local p, on = cam:WorldToViewportPoint(headPart.Position)
				if on and p.Z > 0 then
					set.head.Visible = true
					set.head.Position = Vector2.new(p.X, p.Y)
					set.head.Radius = math.max(2, h / 12)
					set.head.Color = col
				end
			end

			-- skeleton
			local bones = hum.RigType == Enum.HumanoidRigType.R15 and R15_BONES or R6_BONES
			for i = 1, MAX_BONES do
				local ln = set["sk" .. i]
				local shown = false
				local pair = bones[i]
				if S.skeleton and pair then
					local a, b = c:FindFirstChild(pair[1]), c:FindFirstChild(pair[2])
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
				if i == MAX_BONES then maskSet(set) end
			end
		end
	end)
end
onCleanup(function() ESP.stop() end)

