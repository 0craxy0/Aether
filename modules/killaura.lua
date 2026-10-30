local A = ...
local new, T, notify, onCleanup, TF, SA = A.new, A.T, A.notify, A.onCleanup, A.TF, A.SA
local LP, Players, RunService, UserInputService = A.LP, A.Players, A.RunService, A.UserInputService
local screen, charParts = A.screen, A.charParts

local KA = {
	active = false, conn = nil, last = 0, target = nil, kills = 0,
	reach = {}, hooked = {}, ring = nil, hl = nil,
	s = {
		range = 15, mode = "Nearest", maxTargets = 3, delay = 100, swings = 1,
		method = "Activate", hitPart = "HumanoidRootPart", key = "Always",
		autoEquip = true, faceTarget = true, behind = false, behindDist = 3,
		teamCheck = true, ffCheck = true, friendCheck = false, wallCheck = false,
		sticky = false, stopHealth = 0, skipSitting = false,
		reachOn = false, reachSize = 12,
		showRing = true, highlight = true, killNotify = false,
	},
}
A.KA = KA

local kaParams = RaycastParams.new()
kaParams.FilterType = Enum.RaycastFilterType.Exclude

local function kaKeyHeld()
	local k = KA.s.key
	if k == "Always" then return true end
	if k == "Right Mouse" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
	if k == "Left Mouse" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
	local kc = Enum.KeyCode[k]
	return kc ~= nil and UserInputService:IsKeyDown(kc)
end

local function kaGetTool(char, hum)
	local tool = char:FindFirstChildOfClass("Tool")
	if tool then return tool end
	if not KA.s.autoEquip then return nil end
	local bp = LP:FindFirstChildOfClass("Backpack")
	local t = bp and bp:FindFirstChildOfClass("Tool")
	if t then
		pcall(function() hum:EquipTool(t) end)
		return t
	end
end

local function kaRestoreReach()
	for handle, size in pairs(KA.reach) do
		if handle and handle.Parent then pcall(function() handle.Size = size end) end
	end
	KA.reach = {}
end

local function kaApplyReach(tool)
	local handle = tool and tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then return end
	if not KA.reach[handle] then KA.reach[handle] = handle.Size end
	local r = KA.s.reachSize
	handle.Size = Vector3.new(r, r, r)
	handle.Massless = true
end

local function kaTrackKills(hum)
	if KA.hooked[hum] then return end
	KA.hooked[hum] = true
	hum.Died:Connect(function()
		KA.kills += 1
		KA.hooked[hum] = nil
		if KA.s.killNotify then notify("Kill aura", "kills this session: " .. KA.kills, "good") end
	end)
end

local function kaCandidates(myRoot)
	local s = KA.s
	local list = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LP then
			local c = plr.Character
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local dist = (root.Position - myRoot.Position).Magnitude
				local ok = dist <= s.range and not TF.white[plr.UserId]
				if ok and s.teamCheck and LP.Team ~= nil and plr.Team == LP.Team then ok = false end
				if ok and s.ffCheck and c:FindFirstChildOfClass("ForceField") then ok = false end
				if ok and s.skipSitting and hum.Sit then ok = false end
				if ok and s.friendCheck and SA.friends[plr] then ok = false end
				if ok and s.wallCheck then
					kaParams.FilterDescendantsInstances = { LP.Character, c }
					if workspace:Raycast(myRoot.Position, root.Position - myRoot.Position, kaParams) then ok = false end
				end
				if ok then
					local metric = dist
					if s.mode == "Lowest health" then metric = hum.Health end
					if TF.black[plr.UserId] then metric = -1e9 end
					list[#list + 1] = { plr = plr, char = c, hum = hum, root = root, dist = dist, metric = metric }
				end
			end
		end
	end
	table.sort(list, function(a, b) return a.metric < b.metric end)
	return list
end

local KA_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

local function kaTouch(handle, char)
	if not firetouchinterest then return end
	local mode = KA.s.hitPart
	local parts = {}
	if mode == "All" then
		for _, n in ipairs(KA_PARTS) do
			local p = char:FindFirstChild(n)
			if p then parts[#parts + 1] = p end
		end
	else
		local p = char:FindFirstChild(mode)
			or char:FindFirstChild("Torso")
			or char:FindFirstChild("HumanoidRootPart")
		if p then parts[1] = p end
	end
	for _, p in ipairs(parts) do
		pcall(firetouchinterest, handle, p, 0)
		pcall(firetouchinterest, handle, p, 1)
	end
end

function KA.stop()
	KA.active = false
	if KA.conn then KA.conn:Disconnect(); KA.conn = nil end
	if KA.ring then pcall(function() KA.ring:Destroy() end); KA.ring = nil end
	if KA.hl then pcall(function() KA.hl:Destroy() end); KA.hl = nil end
	kaRestoreReach()
	KA.target = nil
end

function KA.start()
	if KA.conn then return end
	KA.active = true
	local warned = false

	KA.conn = RunService.Heartbeat:Connect(function()
		local s = KA.s
		local char, hum, root = charParts()
		local cam = workspace.CurrentCamera

		-- range ring
		if s.showRing and root and cam then
			if not KA.ring then
				KA.ring = new("Part", {
					Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false,
					CanTouch = false, Material = Enum.Material.Neon, Color = T.accent, Transparency = 0.85,
					Parent = cam,
				})
			end
			KA.ring.Color = T.accent
			KA.ring.Size = Vector3.new(0.2, s.range * 2, s.range * 2)
			KA.ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
		elseif KA.ring then
			KA.ring:Destroy(); KA.ring = nil
		end

		if not char or not hum or hum.Health <= 0 then KA.target = nil; return end
		if not kaKeyHeld() then
			KA.target = nil
			if KA.hl then KA.hl.Adornee = nil end
			return
		end
		if s.stopHealth > 0 and hum.Health / math.max(hum.MaxHealth, 1) * 100 < s.stopHealth then return end

		local list = kaCandidates(root)
		local picked = {}
		if #list > 0 then
			if s.mode == "All in range" then
				for i = 1, math.min(#list, s.maxTargets) do picked[i] = list[i] end
			else
				local first = list[1]
				if s.sticky and KA.target then
					for _, e in ipairs(list) do
						if e.plr == KA.target.plr then first = e; break end
					end
				end
				picked[1] = first
			end
		end
		KA.target = picked[1]

		-- highlight
		if s.highlight and KA.target then
			if not KA.hl then
				KA.hl = Instance.new("Highlight")
				KA.hl.FillTransparency = 0.6
				KA.hl.OutlineColor = Color3.new(1, 1, 1)
				KA.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				KA.hl.Parent = screen
			end
			KA.hl.FillColor = T.bad
			KA.hl.Adornee = KA.target.char
		elseif KA.hl then
			KA.hl.Adornee = nil
		end

		if #picked == 0 then return end

		local tool = kaGetTool(char, hum)
		if tool and s.reachOn then kaApplyReach(tool) end

		-- position / facing
		local t1 = picked[1]
		if s.behind then
			root.CFrame = t1.root.CFrame * CFrame.new(0, 0, s.behindDist)
		end
		if s.faceTarget then
			local tp = t1.root.Position
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(tp.X, root.Position.Y, tp.Z))
		end

		for _, e in ipairs(picked) do kaTrackKills(e.hum) end

		-- attack on cooldown
		if (tick() - KA.last) * 1000 < s.delay then return end
		KA.last = tick()
		if not tool then return end

		local handle = tool:FindFirstChild("Handle")
		for _ = 1, s.swings do
			if s.method == "Activate" or s.method == "Both" then
				pcall(function() tool:Activate() end)
			end
			if s.method == "Touch" or s.method == "Both" then
				if not firetouchinterest then
					if not warned then
						warned = true
						notify("Kill aura", "firetouchinterest unsupported", "bad")
					end
				elseif handle then
					for _, e in ipairs(picked) do kaTouch(handle, e.char) end
				end
			end
		end
	end)
end
onCleanup(KA.stop)

