local A = ...
local new, notify, onCleanup = A.new, A.notify, A.onCleanup
local LP, RunService, UserInputService = A.LP, A.RunService, A.UserInputService
local Lighting, VirtualUser = A.Lighting, A.VirtualUser

function A.charParts()
	local c = LP.Character
	if not c then return end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local root = c:FindFirstChild("HumanoidRootPart")
	if hum and root then return c, hum, root end
end
local charParts = A.charParts

local state = { speed = 16, jump = 50, fov = 70, speedActive = false, jumpActive = false }
A.state = state

local function reapply()
	local _, hum = charParts()
	if not hum then return end
	if state.speedActive then hum.WalkSpeed = state.speed end
	if state.jumpActive then hum.JumpPower = state.jump end
end
local charConn = LP.CharacterAdded:Connect(function()
	task.wait(0.6)
	reapply()
end)
onCleanup(function() charConn:Disconnect() end)

-- fly ---------------------------------------------------------
local fly = { active = false, speed = 55, bv = nil, bg = nil, conn = nil }
A.fly = fly

function fly.stop()
	if fly.conn then fly.conn:Disconnect(); fly.conn = nil end
	if fly.bv then fly.bv:Destroy(); fly.bv = nil end
	if fly.bg then fly.bg:Destroy(); fly.bg = nil end
	local _, hum = charParts()
	if hum then hum.PlatformStand = false end
	fly.active = false
end

function fly.start()
	local _, hum, root = charParts()
	if not root or not hum then return notify("Fly", "no character", "bad") end
	fly.active = true
	hum.PlatformStand = true

	fly.bv = new("BodyVelocity", { MaxForce = Vector3.new(1e5, 1e5, 1e5), Velocity = Vector3.zero, Parent = root })
	fly.bg = new("BodyGyro", { MaxTorque = Vector3.new(1e5, 1e5, 1e5), P = 12000, D = 700, Parent = root })

	local cam = workspace.CurrentCamera
	fly.conn = RunService.RenderStepped:Connect(function()
		if not fly.bv or not fly.bv.Parent then return fly.stop() end
		local dir = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		fly.bv.Velocity = dir.Magnitude > 0 and dir.Unit * fly.speed or Vector3.zero
		fly.bg.CFrame = cam.CFrame
	end)
end
onCleanup(fly.stop)

-- noclip ------------------------------------------------------
local noclipConn
function A.setNoclip(on)
	if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	if not on then return end
	noclipConn = RunService.Stepped:Connect(function()
		local c = LP.Character
		if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end)
end
onCleanup(function() if noclipConn then noclipConn:Disconnect() end end)

-- infinite jump -----------------------------------------------
local ijConn
function A.setInfJump(on)
	if ijConn then ijConn:Disconnect(); ijConn = nil end
	if not on then return end
	ijConn = UserInputService.JumpRequest:Connect(function()
		local _, hum = charParts()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end)
end
onCleanup(function() if ijConn then ijConn:Disconnect() end end)

-- anti-afk ----------------------------------------------------
local afkConn
function A.setAntiAfk(on)
	if afkConn then afkConn:Disconnect(); afkConn = nil end
	if not on then return end
	afkConn = LP.Idled:Connect(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end
onCleanup(function() if afkConn then afkConn:Disconnect() end end)

-- fullbright --------------------------------------------------
local savedLight = {}
function A.setFullbright(on)
	if on then
		savedLight = {
			Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
			Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
			FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
		}
		Lighting.Brightness = 2.5
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
	else
		for k, v in pairs(savedLight) do Lighting[k] = v end
	end
end
onCleanup(function() A.setFullbright(false) end)

-- fog / particles ---------------------------------------------
function A.setNoFog(on)
	Lighting.FogEnd = on and 1e6 or 100000
end

local killedParticles = {}
function A.setNoParticles(on)
	if on then
		for _, d in ipairs(workspace:GetDescendants()) do
			if d:IsA("ParticleEmitter") and d.Enabled then
				d.Enabled = false
				killedParticles[#killedParticles + 1] = d
			end
		end
	else
		for _, d in ipairs(killedParticles) do
			if d and d.Parent then d.Enabled = true end
		end
		killedParticles = {}
	end
end
onCleanup(function() A.setNoParticles(false) end)

