local A = ...
local T, notify, onCleanup, has, TF = A.T, A.notify, A.onCleanup, A.has, A.TF
local LP, Players, RunService, UserInputService = A.LP, A.Players, A.RunService, A.UserInputService
local uiHitCircle, uiHitSeg, uiHitBox = A.uiHitCircle, A.uiHitSeg, A.uiHitBox

local Aim = {
	conn = nil, bound = false, target = nil, rand = 1, lastShot = 0, warnedTrigger = false,
	acquiredAt = 0,
	s = {
		fov = 150, showFov = true, fovFilled = false,
		smooth = 30, method = "Camera", part = "Head",
		priority = "Cursor", aimKey = "Right Mouse",
		wallCheck = true, teamCheck = true, ffCheck = true,
		sticky = false, prediction = 0, maxDist = 1500, jitter = 0,
		snapline = true, targetInfo = true,
		trigger = false, triggerDelay = 80, deadzone = 1.5,
	},
}
A.Aim = Aim

local AIM_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
A.AIM_PARTS = AIM_PARTS

local aimParams = RaycastParams.new()
aimParams.FilterType = Enum.RaycastFilterType.Exclude

-- A nil in FilterDescendantsInstances is not "ignore nothing", it is an argument
-- error on the next Raycast - and LocalPlayer.Character is nil for the frame or
-- two after a respawn. Build the list without holes.
local function aimIgnore(...)
	local list = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		if v then list[#list + 1] = v end
	end
	return list
end

local function aimBlocked(caster, target)
	aimParams.FilterDescendantsInstances = aimIgnore(caster, target)
	return aimParams
end

-- bound by name so the step can be unbound on stop; see Aim.start
local RENDER_NAME = "AetherAim"

local function aimKeyHeld()
	local k = Aim.s.aimKey
	if k == "Always" then return true end
	if k == "Right Mouse" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
	if k == "Left Mouse" then return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
	local kc = Enum.KeyCode[k]
	return kc ~= nil and UserInputService:IsKeyDown(kc)
end

local function aimPickPart(c, cam, mouse)
	local mode = Aim.s.part
	if mode == "Head" then return c:FindFirstChild("Head") end
	if mode == "Torso" then
		return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
	end
	local list = {}
	for _, n in ipairs(AIM_PARTS) do
		local p = c:FindFirstChild(n)
		if p then list[#list + 1] = p end
	end
	if #list == 0 then return nil end
	if mode == "Random" then return list[(Aim.rand - 1) % #list + 1] end
	local best, bestD
	for _, p in ipairs(list) do
		local sp, on = cam:WorldToViewportPoint(p.Position)
		if on and sp.Z > 0 then
			local d = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
			if not bestD or d < bestD then best, bestD = p, d end
		end
	end
	return best or list[1]
end

local function aimEvaluate(plr, cam, mouse, ignoreFov)
	if TF.white[plr.UserId] then return nil end
	local s = Aim.s
	local c = plr.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then return nil end
	if s.teamCheck and LP.Team ~= nil and plr.Team == LP.Team then return nil end
	if s.ffCheck and c:FindFirstChildOfClass("ForceField") then return nil end
	local dist = (root.Position - cam.CFrame.Position).Magnitude
	if dist > s.maxDist then return nil end
	local part = aimPickPart(c, cam, mouse)
	if not part then return nil end
	local pos = part.Position
	if s.prediction > 0 then pos = pos + root.AssemblyLinearVelocity * (s.prediction / 1000) end
	local sp, on = cam:WorldToViewportPoint(pos)
	if not on or sp.Z <= 0 then return nil end
	local screenPos = Vector2.new(sp.X, sp.Y)
	local d2 = (screenPos - mouse).Magnitude
	if not ignoreFov and d2 > s.fov and not TF.black[plr.UserId] then return nil end
	if s.wallCheck then
		if workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, aimBlocked(LP.Character, c)) then return nil end
	end
	local metric = d2
	if s.priority == "Distance" then metric = dist
	elseif s.priority == "Lowest health" then metric = hum.Health end
	if TF.black[plr.UserId] then metric = -1e9 end
	return { plr = plr, part = part, pos = pos, screen = screenPos, metric = metric, hum = hum, dist = dist }
end

function Aim.stop()
	if Aim.bound then
		pcall(function() RunService:UnbindFromRenderStep(RENDER_NAME) end)
		Aim.bound = false
	end
	if Aim.conn then Aim.conn:Disconnect(); Aim.conn = nil end
	for _, k in ipairs({ "circle", "line", "text" }) do
		if Aim[k] then pcall(function() Aim[k]:Remove() end); Aim[k] = nil end
	end
	Aim.target = nil
end

function Aim.start()
	if Aim.conn or Aim.bound then return end
	if has.drawing then
		Aim.circle = Drawing.new("Circle")
		Aim.circle.NumSides = 64
		Aim.circle.Thickness = 1
		Aim.line = Drawing.new("Line")
		Aim.line.Thickness = 1
		Aim.text = Drawing.new("Text")
		Aim.text.Center = true
		Aim.text.Outline = true
		Aim.text.Size = 13
		Aim.text.Font = 2
		Aim.text.Color = Color3.new(1, 1, 1)
	end

	local function step(dt)
		local cam = workspace.CurrentCamera
		if not cam then return end
		local s = Aim.s
		local m = UserInputService:GetMouseLocation()

		-- Acquisition runs on every frame the key is down, never only on the press:
		-- a target that becomes reachable mid-hold is picked up on the frame it
		-- becomes reachable, and one that dies or leaves the FOV is replaced by the
		-- next best candidate on that same frame.
		local held = aimKeyHeld()
		local newT
		if held then
			if s.sticky and Aim.target then
				newT = aimEvaluate(Aim.target.plr, cam, m, true)
			end
			if not newT then
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr ~= LP then
						local t = aimEvaluate(plr, cam, m, false)
						if t and (not newT or t.metric < newT.metric) then newT = t end
					end
				end
			end
		end
		local previous = Aim.target and Aim.target.plr
		if newT and newT.plr ~= previous then
			Aim.rand = math.random(1, 4)
			Aim.acquiredAt = os.clock() -- fresh target: close the gap now, smooth after
		end
		Aim.target = newT

		-- aim
		if newT then
			local delta = newT.screen - m
			if s.jitter > 0 then
				delta = delta + Vector2.new((math.random() - 0.5) * 2 * s.jitter, (math.random() - 0.5) * 2 * s.jitter)
			end
			if delta.Magnitude > s.deadzone then
				local alpha = 1 - (s.smooth / 100) ^ (math.max(dt, 1 / 240) * 60)
				alpha = math.clamp(alpha, 0.01, 1)
				-- a new target is snapped at rather than eased at, so the lock lands on
				-- the frame it becomes available instead of drifting in
				if os.clock() - (Aim.acquiredAt or 0) < 0.15 then
					alpha = math.clamp(alpha * 2.5, 0.01, 1)
				end
				if s.method == "Mouse" and mousemoverel then
					mousemoverel(delta.X * alpha, delta.Y * alpha)
				else
					cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, newT.pos), alpha)
				end
			end
		end

		-- triggerbot
		if s.trigger and LP.Character then
			local click = mouse1click or mouse1press
			if not click then
				if not Aim.warnedTrigger then
					Aim.warnedTrigger = true
					notify("Triggerbot", "mouse1click unsupported", "bad")
				end
			elseif (tick() - Aim.lastShot) * 1000 >= s.triggerDelay then
				local ray = cam:ViewportPointToRay(m.X, m.Y)
				local res = workspace:Raycast(ray.Origin, ray.Direction * s.maxDist, aimBlocked(LP.Character))
				if res then
					local model = res.Instance:FindFirstAncestorOfClass("Model")
					local plr = model and Players:GetPlayerFromCharacter(model)
					local hum = model and model:FindFirstChildOfClass("Humanoid")
					if plr and plr ~= LP and hum and hum.Health > 0 and not TF.white[plr.UserId]
						and not (s.teamCheck and LP.Team ~= nil and plr.Team == LP.Team) then
						Aim.lastShot = tick()
						pcall(click)
					end
				end
			end
		end

		-- drawings
		if Aim.circle then
			Aim.circle.Visible = s.showFov and not uiHitCircle(m, s.fov)
			Aim.circle.Position = m
			Aim.circle.Radius = s.fov
			Aim.circle.Filled = s.fovFilled
			Aim.circle.Transparency = s.fovFilled and 0.12 or 1
			Aim.circle.Color = newT and T.good or T.accent
			Aim.line.Visible = s.snapline and newT ~= nil and not uiHitSeg(m, newT.screen)
			Aim.text.Visible = s.targetInfo and newT ~= nil and not uiHitBox(newT.screen.X - 90, newT.screen.Y + 8, 180, 18)
			if newT then
				Aim.line.From = m
				Aim.line.To = newT.screen
				Aim.line.Color = T.good
				Aim.text.Position = newT.screen + Vector2.new(0, 14)
				Aim.text.Text = string.format("%s  [%dm]  %d hp", newT.plr.Name, math.floor(newT.dist), math.floor(newT.hum.Health))
			end
		end
	end

	-- Bound one step *after* the default camera. A plain RenderStepped write is
	-- overwritten by the camera module later in the same frame, which is why the
	-- aim only ever appeared to lock when the target was already under the
	-- crosshair and the leftover correction was under the deadzone.
	local bound = pcall(function()
		RunService:UnbindFromRenderStep(RENDER_NAME)
		RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, step)
	end)
	Aim.bound = bound
	if not bound then Aim.conn = RunService.RenderStepped:Connect(step) end
end
onCleanup(Aim.stop)

