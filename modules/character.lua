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

local state = { speed = 16, jump = 50, fov = 70, speedActive = false, jumpActive = false, anchored = false }
A.state = state

-- Anchor that survives a respawn ------------------------------------------------
-- The old control was a button that flipped HumanoidRootPart.Anchored and forgot
-- about it, so a reset left you falling and the button claiming to be on. Storing
-- the intent in state and replaying it from reapply() means the anchor comes back
-- with the character, which is the only version of it that is useful.
local anchorConn

local function applyAnchor()
	local _, _, root = charParts()
	if root then root.Anchored = state.anchored end
end

function A.setAnchor(on)
	state.anchored = on and true or false
	applyAnchor()
	if anchorConn then anchorConn:Disconnect(); anchorConn = nil end
	if not state.anchored then return end
	-- A respawn builds a new root on its own schedule; sit on it until it exists
	-- rather than racing CharacterAdded by a fixed delay.
	local tries = 0
	anchorConn = LP.CharacterAdded:Connect(function()
		task.spawn(function()
			while state.anchored and tries < 60 do
				tries += 1
				task.wait(0.1)
				local _, _, root = charParts()
				if root then
					root.Anchored = true
					return
				end
			end
		end)
	end)
end

local function reapply()
	local _, hum, root = charParts()
	if not hum then return end
	if state.speedActive then hum.WalkSpeed = state.speed end
	if state.jumpActive then
		hum.UseJumpPower = true
		hum.JumpPower = state.jump
	end
	if state.anchored and root then root.Anchored = true end
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
local ncSaved = {}

local function restoreCollide()
	for p in pairs(ncSaved) do
		if p.Parent then pcall(function() p.CanCollide = true end) end
		ncSaved[p] = nil
	end
end

function A.setNoclip(on)
	if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
	if not on then return restoreCollide() end -- switching noclip off has to put collision back
	noclipConn = RunService.Stepped:Connect(function()
		local c = LP.Character
		if not c then return end
		for _, p in ipairs(c:GetDescendants()) do
			if p:IsA("BasePart") and p.CanCollide then
				ncSaved[p] = true
				p.CanCollide = false
			end
		end
	end)
end
onCleanup(function()
	if noclipConn then noclipConn:Disconnect() end
	restoreCollide()
end)

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
		-- Only snapshot the first time. Re-enabling used to overwrite the saved
		-- values with the already-bright ones, so unloading could never put the
		-- map's own lighting back.
		if next(savedLight) == nil then
			savedLight = {
				Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
				Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
				FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
			}
		end
		Lighting.Brightness = 2.5
		Lighting.ClockTime = 14
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
	else
		for k, v in pairs(savedLight) do Lighting[k] = v end
		savedLight = {}
	end
end
onCleanup(function() A.setFullbright(false) end)

-- anti-void ----------------------------------------------------
-- Maps that do not kill you under the floor leave you falling forever (or bounce
-- you back with everything reset). Keep the last place the character was really
-- standing and put it back there once it drops past the world's destroy height.
local voidConn, voidSafe, voidFloor

function A.setAntiVoid(on)
	if voidConn then voidConn:Disconnect(); voidConn = nil end
	voidSafe = nil
	if not on then return end

	local ok, fh = pcall(function() return workspace.FallenPartsDestroyHeight end)
	voidFloor = (ok and type(fh) == "number") and fh or -500

	voidConn = RunService.Heartbeat:Connect(function()
		local _, hum, root = charParts()
		if not hum or not root or hum.Health <= 0 then
			voidSafe = nil -- never carry a corpse's position over to the respawn
			return
		end
		if hum.FloorMaterial ~= Enum.Material.Air and root.Position.Y > voidFloor + 50 then
			voidSafe = root.CFrame -- grounded and clear: worth coming back to
		elseif voidSafe and root.Position.Y < voidFloor + 25 then
			root.CFrame = voidSafe
			root.AssemblyLinearVelocity = Vector3.zero
			voidSafe = nil
			notify("Anti-void", "pulled back to the last safe spot", "good")
		end
	end)
end
onCleanup(function() A.setAntiVoid(false) end)

-- fog / particles ---------------------------------------------
local savedFog
function A.setNoFog(on)
	if on then
		if not savedFog then savedFog = Lighting.FogEnd end
		Lighting.FogEnd = 1e6
	elseif savedFog then
		Lighting.FogEnd = savedFog -- restore the map's own fog, never a guessed value
		savedFog = nil
	end
end
onCleanup(function()
	if savedFog then Lighting.FogEnd = savedFog; savedFog = nil end
end)

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

