local A = ...
local new, onCleanup = A.new, A.onCleanup
local T = A.T
local LP, RunService, Lighting, Players = A.LP, A.RunService, A.Lighting, A.Players
local charParts = A.charParts

-- World tools ---------------------------------------------------------------
-- Four things that are about the place you are standing in rather than about
-- your character: find an instance, go to it, outline the ones you care about,
-- and turn the scenery down when the device is struggling.

local W = {
	-- highlight
	hl = false,
	pattern = "",
	maxDist = 300,
	maxObjects = 24,
	rescanEvery = 1.5,
	objects = {},
	lastScan = 0,
	-- low graphics
	lowg = false,
	savedLight = nil,
	killedEffects = {},
	killedImages = {},
}
A.world = W

local function pathOf(inst)
	local bits = {}
	local node = inst
	for _ = 1, 5 do
		if not node or node == workspace or node == game then break end
		table.insert(bits, 1, node.Name)
		node = node.Parent
	end
	return table.concat(bits, ".")
end

-- find / teleport --------------------------------------------------------------

-- Name search over Workspace, one pass, capped. Models and BaseParts both count,
-- because half of what people look for is a model ("Shop", "Spawn") and half is
-- a part ("WinPad").
function W.search(query, limit)
	query = tostring(query or ""):lower()
	if query == "" then return {} end
	limit = limit or 40
	local hits = {}
	local ok, list = pcall(function() return workspace:GetDescendants() end)
	if not ok then return hits end
	for _, inst in ipairs(list) do
		if #hits >= limit then break end
		if inst:IsA("BasePart") or inst:IsA("Model") then
			if inst.Name:lower():find(query, 1, true) then
				local okPos, pos
				if inst:IsA("BasePart") then
					pos = inst.Position
				else
					local okPivot, pivot = pcall(function() return inst:GetPivot() end)
					pos = okPivot and pivot and pivot.Position or nil
				end
				if pos then
					hits[#hits + 1] = {
						inst = inst, name = inst.Name, path = pathOf(inst), pos = pos,
					}
				end
			end
		end
	end
	return hits
end

function W.tpTo(pos)
	local _, _, root = charParts()
	if not root then return false, "no character" end
	if A.guard and A.guard.expect then A.guard.expect(2) end
	root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

-- object highlight ---------------------------------------------------------------

local function newDrawing(kind, props)
	local ok, d = pcall(function()
		local obj = Drawing.new(kind)
		for k, v in pairs(props) do obj[k] = v end
		return obj
	end)
	if ok then return d end
	return nil
end

local function newSet()
	local set = {
		out = newDrawing("Square", { Filled = false, Thickness = 3, Color = Color3.new(0, 0, 0), Visible = false }),
		box = newDrawing("Square", { Filled = false, Thickness = 1, Visible = false }),
		text = newDrawing("Text", { Center = true, Outline = true, Size = 12, Visible = false }),
	}
	if not (set.out and set.box and set.text) then return nil end
	return set
end

local function dropAll()
	for _, o in ipairs(W.objects) do
		for _, d in pairs(o.set) do pcall(function() d:Remove() end) end
	end
	W.objects = {}
end

-- Incremental, not a full rebuild. The old version destroyed and recreated every
-- Drawing object on every scan, which is a visible hitch in a busy place once a
-- second and a half. Objects that still qualify keep the set they already have;
-- only the ones that walked out of range are removed and only genuinely new
-- matches allocate.
local function rescan()
	if not W.hl or W.pattern == "" then
		dropAll()
		return
	end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local camPos = cam.CFrame.Position
	local want = W.pattern:lower()

	local kept, live = {}, {}
	for _, o in ipairs(W.objects) do
		local inst = o.inst
		local p = (inst and inst.Parent) and inst.Position or nil
		if p and (p - camPos).Magnitude <= W.maxDist then
			kept[#kept + 1] = o
			live[inst] = true
		else
			for _, d in pairs(o.set) do pcall(function() d:Remove() end) end
		end
	end
	W.objects = kept
	if #kept >= W.maxObjects then return end

	local ok, list = pcall(function() return workspace:GetDescendants() end)
	if not ok then return end
	for _, inst in ipairs(list) do
		if #W.objects >= W.maxObjects then break end
		if not live[inst] and inst:IsA("BasePart") and inst.Name:lower():find(want, 1, true) then
			local p = inst.Position
			if (p - camPos).Magnitude <= W.maxDist then
				local set = newSet()
				if set then
					W.objects[#W.objects + 1] = { inst = inst, set = set }
				end
			end
		end
	end
end

function W.setHighlight(on)
	on = on and true or false
	if not on then
		W.hl = false
		dropAll()
		return true
	end
	if not A.has.drawing then
		return false, "Drawing API unavailable in this executor"
	end
	W.hl = true
	W.lastScan = 0
	return true
end

local drawConn = RunService.RenderStepped:Connect(function()
	if not W.hl then return end
	local cam = workspace.CurrentCamera
	if not cam then return end
	local now = os.clock()
	if now - W.lastScan >= W.rescanEvery then
		W.lastScan = now
		pcall(rescan)
	end
	local camPos = cam.CFrame.Position
	for _, o in ipairs(W.objects) do
		local inst, set = o.inst, o.set
		local visible = inst and inst.Parent
		local sp, onScreen, dist
		if visible then
			local pos = inst.Position
			dist = (pos - camPos).Magnitude
			local sx, sy, sz = cam:WorldToViewportPoint(pos)
			sp = Vector2.new(sx, sy)
			onScreen = sz > 0 and dist <= W.maxDist
			visible = onScreen
		end
		if visible then
			local size = math.clamp(1200 / math.max(dist, 1), 10, 120)
			local tl = Vector2.new(sp.X - size / 2, sp.Y - size / 2)
			set.out.Visible = true
			set.out.Position = tl
			set.out.Size = Vector2.new(size, size)
			set.box.Visible = true
			set.box.Position = tl
			set.box.Size = Vector2.new(size, size)
			set.box.Color = T.accent
			set.text.Visible = true
			-- the label only changes when the name does or the distance crosses a
			-- whole stud; formatting a string per object per frame is the one
			-- allocation this loop did not need
			local d = math.floor(dist)
			if o._n ~= inst.Name or o._d ~= d then
				o._n, o._d = inst.Name, d
				set.text.Text = string.format("%s  %dm", inst.Name, d)
			end
			set.text.Position = Vector2.new(sp.X, sp.Y + size / 2 + 9)
			set.text.Color = Color3.new(1, 1, 1)
			-- Drawing does not clip to the panel, so drop anything that lands on it
			if A.maskSet then pcall(A.maskSet, set) end
		else
			for _, d in pairs(set) do d.Visible = false end
		end
	end
end)

function W.clearHighlight()
	for _, o in ipairs(W.objects) do
		for _, d in pairs(o.set) do pcall(function() d:Remove() end) end
	end
	W.objects = {}
end

onCleanup(function()
	drawConn:Disconnect()
	W.clearHighlight()
end)

-- low graphics -----------------------------------------------------------------

-- Deliberately does NOT touch FogEnd or GlobalShadows: those belong to Remove fog
-- and Fullbright, and two switches owning the same property means whichever was
-- turned off last wins. This one owns the effects and the environment lighting.
local EFFECT_CLASSES = { "ParticleEmitter", "Trail", "Beam", "Smoke", "Fire", "Sparkles" }
local IMAGE_CLASSES = { "Decal", "Texture" }

function W.lowGraphics(on)
	on = on and true or false
	if on == W.lowg then return end
	W.lowg = on

	if on then
		if not W.savedLight then
			W.savedLight = {
				EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
				EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
			}
		end
		pcall(function()
			Lighting.EnvironmentDiffuseScale = 0
			Lighting.EnvironmentSpecularScale = 0
		end)
		W.killedEffects = {}
		W.killedImages = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			for _, cls in ipairs(EFFECT_CLASSES) do
				if d:IsA(cls) and d.Enabled then
					d.Enabled = false
					W.killedEffects[#W.killedEffects + 1] = d
					break
				end
			end
			for _, cls in ipairs(IMAGE_CLASSES) do
				if d:IsA(cls) and d.Transparency < 1 then
					W.killedImages[#W.killedImages + 1] = { obj = d, t = d.Transparency }
					d.Transparency = 1
					break
				end
			end
		end
	else
		for _, d in ipairs(W.killedEffects) do
			if d and d.Parent then pcall(function() d.Enabled = true end) end
		end
		for _, rec in ipairs(W.killedImages) do
			if rec.obj and rec.obj.Parent then pcall(function() rec.obj.Transparency = rec.t end) end
		end
		W.killedEffects, W.killedImages = {}, {}
		if W.savedLight then
			pcall(function()
				Lighting.EnvironmentDiffuseScale = W.savedLight.EnvironmentDiffuseScale
				Lighting.EnvironmentSpecularScale = W.savedLight.EnvironmentSpecularScale
			end)
			W.savedLight = nil
		end
	end
end
onCleanup(function() if W.lowg then W.lowGraphics(false) end end)

-- server info -------------------------------------------------------------------

function W.info()
	local ping = -1
	pcall(function()
		local v = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
		if type(v) == "number" then ping = math.floor(v + 0.5) end
	end)
	return {
		place = tostring(game.PlaceId),
		job = tostring(game.JobId),
		players = #Players:GetPlayers(),
		uptime = math.floor(workspace.DistributedGameTime or 0),
		ping = ping,
		buddy = LP.Name,
		userId = tostring(LP.UserId),
		executor = tostring(A.executorName or "?"),
		build = tostring(A.build or "?"),
		profile = tostring(A.profile or "?"),
	}
end
