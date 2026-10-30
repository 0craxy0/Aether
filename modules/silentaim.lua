local A = ...
local T, notify, onCleanup, has, TF = A.T, A.notify, A.onCleanup, A.has, A.TF
local LP, Players, RunService, UserInputService = A.LP, A.Players, A.RunService, A.UserInputService
local uiHitCircle, uiHitSeg, uiHitBox = A.uiHitCircle, A.uiHitSeg, A.uiHitBox
local AIM_PARTS = A.AIM_PARTS

local SA = {
	active = false, conn = nil, target = nil, installed = false,
	rollAt = 0, rollOk = true, rollHead = false, rollOff = Vector3.zero,
	friends = {}, mouse = nil, randIdx = 1,
	s = {
		fov = 180, showFov = true, fovFilled = false, fovOrigin = "Cursor",
		part = "Head", priority = "Cursor", key = "Always",
		hitChance = 100, headChance = 60, spread = 0, prediction = 0,
		wallCheck = true, teamCheck = true, ffCheck = true, friendCheck = false,
		sticky = false, maxDist = 1500, minHealth = 0,
		mRaycast = true, mFindPart = true, mScreenRay = true, mMouse = true,
		snapline = false, targetInfo = true, targetDot = true,
	},
}
A.SA = SA

local SA_FIND = {
	FindPartOnRay = true, FindPartOnRayWithIgnoreList = true, FindPartOnRayWithWhitelist = true,
	findPartOnRay = true, findPartOnRayWithIgnoreList = true, findPartOnRayWithWhitelist = true,
}
local saParams = RaycastParams.new()
saParams.FilterType = Enum.RaycastFilterType.Exclude

local function saTrackFriend(plr)
	task.spawn(function()
		local ok, r = pcall(function() return LP:IsFriendsWith(plr.UserId) end)
		if ok then SA.friends[plr] = r end
	end)
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= LP then saTrackFriend(p) end end
local saAdded = Players.PlayerAdded:Connect(saTrackFriend)
local saRemoved = Players.PlayerRemoving:Connect(function(p) SA.friends[p] = nil end)
onCleanup(function() saAdded:Disconnect(); saRemoved:Disconnect() end)

local function saKeyHeld()
	local k = SA.s.key
	if k == "Always" then return true end
	if k == "Right Mouse" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
	if k == "Left Mouse" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
	local kc = Enum.KeyCode[k]
	return kc ~= nil and UserInputService:IsKeyDown(kc)
end

local function saPickPart(c, cam, origin)
	local mode = SA.s.part
	local head = c:FindFirstChild("Head")
	local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
	if mode == "Head" then return head or torso end
	if mode == "Torso" or mode == "Mixed" then return torso or head end
	local list = {}
	for _, n in ipairs(AIM_PARTS) do
		local p = c:FindFirstChild(n)
		if p then list[#list + 1] = p end
	end
	if #list == 0 then return nil end
	if mode == "Random" then return list[(SA.randIdx - 1) % #list + 1] end
	local best, bestD
	for _, p in ipairs(list) do
		local sp, on = cam:WorldToViewportPoint(p.Position)
		if on and sp.Z > 0 then
			local d = (Vector2.new(sp.X, sp.Y) - origin).Magnitude
			if not bestD or d < bestD then best, bestD = p, d end
		end
	end
	return best or list[1]
end

local function saEvaluate(plr, cam, origin, ignoreFov)
	if TF.white[plr.UserId] then return nil end
	local s = SA.s
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 or hum.Health < s.minHealth then return nil end
	if s.teamCheck and LP.Team ~= nil and plr.Team == LP.Team then return nil end
	if s.ffCheck and c:FindFirstChildOfClass("ForceField") then return nil end
	if s.friendCheck and SA.friends[plr] then return nil end
	local dist = (root.Position - cam.CFrame.Position).Magnitude
	if dist > s.maxDist then return nil end
	local part = saPickPart(c, cam, origin)
	if not part then return nil end
	local sp, on = cam:WorldToViewportPoint(part.Position)
	if not on or sp.Z <= 0 then return nil end
	local screenPos = Vector2.new(sp.X, sp.Y)
	local d2 = (screenPos - origin).Magnitude
	if not ignoreFov and d2 > s.fov and not TF.black[plr.UserId] then return nil end
	if s.wallCheck then
		saParams.FilterDescendantsInstances = { LP.Character, c }
		if workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, saParams) then return nil end
	end
	local metric = d2
	if s.priority == "Distance" then metric = dist
	elseif s.priority == "Lowest health" then metric = hum.Health end
	if TF.black[plr.UserId] then metric = -1e9 end
	return { plr = plr, part = part, screen = screenPos, metric = metric, hum = hum, dist = dist }
end

-- where should shots go right now (called from inside the hooks)
function SA.aimPos()
	local t = SA.target
	if not t then return nil end
	local s = SA.s
	if tick() - SA.rollAt > 0.12 then
		SA.rollAt = tick()
		SA.rollOk = math.random(100) <= s.hitChance
		SA.rollHead = math.random(100) <= s.headChance
		SA.rollOff = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2 * s.spread
	end
	if not SA.rollOk then return nil end
	local c = t.plr.Character
	if not c then return nil end
	local part = t.part
	if s.part == "Mixed" then
		part = SA.rollHead and c:FindFirstChild("Head") or t.part
	end
	if not part or not part.Parent then return nil end
	local pos = part.Position
	local root = c:FindFirstChild("HumanoidRootPart")
	if s.prediction > 0 and root then pos = pos + root.AssemblyLinearVelocity * (s.prediction / 1000) end
	if s.spread > 0 then pos = pos + SA.rollOff end
	return pos, part
end

function SA.process(self, method, ...)
	local s = SA.s
	if self == workspace then
		if method == "Raycast" then
			if not s.mRaycast then return end
			local origin, dir = ...
			if typeof(origin) ~= "Vector3" or typeof(dir) ~= "Vector3" then return end
			local pos = SA.aimPos()
			if not pos then return end
			local a = table.pack(...)
			a[2] = (pos - origin).Unit * dir.Magnitude
			return "args", a
		elseif SA_FIND[method] then
			if not s.mFindPart then return end
			local ray = ...
			if typeof(ray) ~= "Ray" then return end
			local pos = SA.aimPos()
			if not pos then return end
			local a = table.pack(...)
			a[1] = Ray.new(ray.Origin, (pos - ray.Origin).Unit * ray.Direction.Magnitude)
			return "args", a
		end
	elseif s.mScreenRay and (method == "ScreenPointToRay" or method == "ViewportPointToRay") and self == workspace.CurrentCamera then
		local pos = SA.aimPos()
		if not pos then return end
		local origin = self.CFrame.Position
		return "ret", Ray.new(origin, (pos - origin).Unit)
	end
end

function SA.install()
	if SA.installed then return true end
	if not (hookmetamethod and getnamecallmethod and checkcaller) then return false end
	if getgenv().AetherSAHooked then SA.installed = true; return true end
	local wrap = newcclosure or function(f) return f end

	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", wrap(function(self, ...)
		local cur = getgenv().AetherSA
		if cur and cur.active and not checkcaller() then
			local method = getnamecallmethod()
			local ok, kind, v = pcall(cur.process, self, method, ...)
			if ok then
				if kind == "args" then
					if setnamecallmethod then setnamecallmethod(method) end
					return oldNamecall(self, table.unpack(v, 1, v.n))
				elseif kind == "ret" then
					return v
				end
			end
			if setnamecallmethod then setnamecallmethod(method) end
		end
		return oldNamecall(self, ...)
	end))

	local oldIndex
	oldIndex = hookmetamethod(game, "__index", wrap(function(self, key)
		local cur = getgenv().AetherSA
		if cur and cur.active and cur.s.mMouse and self == cur.mouse
			and (key == "Hit" or key == "Target") and not checkcaller() then
			local ok, pos, part = pcall(cur.aimPos)
			if ok and pos then
				if key == "Hit" then return CFrame.new(pos) end
				return part
			end
		end
		return oldIndex(self, key)
	end))

	getgenv().AetherSAHooked = true
	SA.installed = true
	return true
end

function SA.stop()
	SA.active = false
	if SA.conn then SA.conn:Disconnect(); SA.conn = nil end
	for _, k in ipairs({ "circle", "line", "text", "dot" }) do
		if SA[k] then pcall(function() SA[k]:Remove() end); SA[k] = nil end
	end
	SA.target = nil
	if getgenv().AetherSA == SA then getgenv().AetherSA = nil end
end

function SA.start()
	if SA.conn then return true end
	if not SA.install() then
		notify("Silent aim", "needs hookmetamethod / checkcaller", "bad")
		return false
	end
	SA.mouse = LP:GetMouse()
	getgenv().AetherSA = SA
	SA.active = true

	if has.drawing then
		SA.circle = Drawing.new("Circle")
		SA.circle.NumSides = 64
		SA.circle.Thickness = 1
		SA.line = Drawing.new("Line")
		SA.line.Thickness = 1
		SA.dot = Drawing.new("Circle")
		SA.dot.Filled = true
		SA.dot.Radius = 4
		SA.dot.NumSides = 16
		SA.text = Drawing.new("Text")
		SA.text.Center = true
		SA.text.Outline = true
		SA.text.Size = 13
		SA.text.Font = 2
		SA.text.Color = Color3.new(1, 1, 1)
	end

	SA.conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local s = SA.s
		local origin = UserInputService:GetMouseLocation()
		if s.fovOrigin == "Center" then origin = cam.ViewportSize / 2 end

		local newT
		if saKeyHeld() then
			if s.sticky and SA.target then
				newT = saEvaluate(SA.target.plr, cam, origin, true)
			end
			if not newT then
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= LP then
						local t = saEvaluate(plr, cam, origin, false)
						if t and (not newT or t.metric < newT.metric) then newT = t end
					end
				end
			end
		end
		if newT and (not SA.target or SA.target.plr ~= newT.plr) then SA.randIdx = math.random(1, 4) end
		SA.target = newT

		if SA.circle then
			SA.circle.Visible = s.showFov and not uiHitCircle(origin, s.fov)
			SA.circle.Position = origin
			SA.circle.Radius = s.fov
			SA.circle.Filled = s.fovFilled
			SA.circle.Transparency = s.fovFilled and 0.12 or 1
			SA.circle.Color = newT and T.good or T.bad
			SA.line.Visible = s.snapline and newT ~= nil and not uiHitSeg(origin, newT.screen)
			SA.dot.Visible = s.targetDot and newT ~= nil and not uiHitCircle(newT.screen, 4)
			SA.text.Visible = s.targetInfo and newT ~= nil and not uiHitBox(newT.screen.X - 90, newT.screen.Y + 8, 180, 18)
			if newT then
				SA.line.From = origin
				SA.line.To = newT.screen
				SA.line.Color = T.good
				SA.dot.Position = newT.screen
				SA.dot.Color = T.good
				SA.text.Position = newT.screen + Vector2.new(0, 14)
				SA.text.Text = string.format("%s  [%dm]  %d hp", newT.plr.Name, math.floor(newT.dist), math.floor(newT.hum.Health))
			end
		end
	end)
	return true
end
onCleanup(SA.stop)
