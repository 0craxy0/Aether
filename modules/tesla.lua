local A = ...
local new, tween, corner, stroke, label = A.new, A.tween, A.corner, A.stroke, A.label
local T, notify, onCleanup = A.T, A.notify, A.onCleanup
local LP, RunService, UserInputService = A.LP, A.RunService, A.UserInputService

-- Flying Tesla Roadster ------------------------------------------------ tesla --
-- Two things, because the car does two things worth cheating: it burns cold gas,
-- and it can be told where to go.
--
--   cold gas   - a value poller, not a packet. Every number in the car (or on it,
--                as an attribute) whose name looks like gas/boost/nitro is held at
--                the highest value it has ever had. That is "infinite" in the
--                only sense that is safe across an update: nothing is invented,
--                the value simply never goes down.
--   auto-pilot - middle-click a point, a scriptable camera orbits it so you can
--                see what you picked, the scroll wheel raises it, then the drive
--                controller holds throttle/steer toward it until it is close.
--
-- Nothing here assumes a class name: the vehicle is "the model my seat is in",
-- and the drive method falls back to pushing the assembly if the seat is not a
-- VehicleSeat (a passenger seat, or a custom chassis).
local TESLA = {}
A.Tesla = TESLA
TESLA.placeId = 1794074302239

-------------------------------------------------------------------------- car --

function TESLA.seat()
	local char = LP.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat.Parent then return seat end
	return nil
end

-- seat, model, root. The model is the outermost Model containing the seat, so a
-- car built as Model > Body > Seat still resolves to the Model the game names.
function TESLA.vehicle()
	local seat = TESLA.seat()
	if not seat then return nil end
	local model = seat:FindFirstAncestorOfClass("Model")
	if not model then return nil end
	while model.Parent and model.Parent:IsA("Model") do model = model.Parent end
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or seat
	return seat, model, root
end

---------------------------------------------------------------------- gas --

local GAS_WORDS = { "coldgas", "boost", "nitro", "nitrous", "nos", "turbo", "charge", "gas" }

local function looksLikeGas(name)
	local n = tostring(name):lower():gsub("[%s_%-]", "")
	for _, w in ipairs(GAS_WORDS) do
		if n:find(w, 1, true) then return true end
	end
	return false
end

local CG = {
	on = false,
	live = {},
	acc = 0,
	status = "off",
	seat = nil,
	conn = nil,
}
TESLA.gas = CG

-- One-off discovery. Attributes first, then Value objects - and not only on the
-- car: a nitro bottle is a Tool, and a game that tracks the bar per player keeps
-- it on the character or in the backpack. A numeric hit keeps the value it was
-- born with as its floor, and the floor rises if the game ever hands out more, so
-- a 100-charge bar stays at 100 instead of being replaced by an invented number.
--
-- Booleans with the same words ("NitroActive", "Boosting") are remembered too:
-- if the game gates the effect on a flag, holding it true is the whole trick.
--
-- Neither of those can beat a value the *server* owns. NitroMul is exactly that
-- case: it is replicated down, the car's speed is computed on the server, and a
-- local SetAttribute is overwritten on the next replication - which looks like
-- "the toggle does nothing". The miss counter in apply() is how we tell that
-- apart from a successful hold, and boost assist is what makes the effect real
-- when it happens.
function CG.scan()
	if CG.scanning then return CG.live end
	CG.scanning = true
	local seat, model = TESLA.vehicle()
	local live = {}
	CG.live = live
	CG.seat = seat
	CG.mirrored = 0
	if not model then
		CG.scanning = false
		CG.status = "not in a vehicle"
		return live
	end

	local function add(inst, kind, name, value)
		live[#live + 1] = { inst = inst, kind = kind, name = name, max = value, miss = 0 }
	end

	local function scanAttrs(inst)
		if not inst then return end
		local ok, attrs = pcall(function() return inst:GetAttributes() end)
		if not (ok and type(attrs) == "table") then return end
		for k, v in pairs(attrs) do
			if looksLikeGas(k) then
				if type(v) == "number" then add(inst, "attr", k, v)
				elseif type(v) == "boolean" then add(inst, "flag", k, true) end
			end
		end
	end

	local function scanValues(inst)
		for _, d in ipairs(inst:GetDescendants()) do
			if (d:IsA("NumberValue") or d:IsA("IntValue")) and looksLikeGas(d.Name) then
				add(d, "value", d.Name, d.Value)
			elseif d:IsA("BoolValue") and looksLikeGas(d.Name) then
				add(d, "bool", d.Name, true)
			end
		end
	end

	scanAttrs(model)
	scanAttrs(seat)
	-- a hard cap: a vehicle that is really a 5,000-part map is not something to
	-- walk five times a second, and no boost value lives past the first 800 parts
	local budget = 800
	for _, d in ipairs(model:GetDescendants()) do
		budget -= 1
		if budget <= 0 then break end
		scanAttrs(d)
	end
	scanValues(model)

	-- player side: character attributes and anything nitro-shaped in the pack
	local char = LP.Character
	scanAttrs(char)
	if char then scanValues(char) end
	local pack = LP:FindFirstChildOfClass("Backpack")
	scanAttrs(pack)
	for _, t in ipairs(pack and pack:GetChildren() or {}) do
		scanAttrs(t)
		for _, d in ipairs(t:GetDescendants()) do scanAttrs(d) end
		scanValues(t)
	end

	if #live == 0 then
		CG.status = "no gas value in " .. model.Name
	else
		CG.status = string.format("%d value%s · %s", #live, #live == 1 and "" or "s", live[1].name)
	end
	CG.scanning = false
	return live
end

function CG.apply()
	for _, f in ipairs(CG.live) do
		local wrote = false

		if f.kind == "value" then
			if f.inst.Parent then
				local v = f.inst.Value
				if v > f.max then f.max = v end
				if v < f.max then
					pcall(function() f.inst.Value = f.max end)
					wrote = true
				end
			end
		elseif f.kind == "bool" then
			if f.inst.Parent and f.inst.Value ~= true then
				pcall(function() f.inst.Value = true end)
				wrote = true
			end
		elseif f.kind == "attr" then
			pcall(function()
				local cur = f.inst:GetAttribute(f.name)
				if type(cur) == "number" then
					if cur > f.max then f.max = cur end
					if cur < f.max then
						f.inst:SetAttribute(f.name, f.max)
						wrote = true
					end
				end
			end)
		elseif f.kind == "flag" then
			if f.inst:GetAttribute(f.name) ~= true then
				pcall(function() f.inst:SetAttribute(f.name, true) end)
				wrote = true
			end
		end

		-- Did the write stick? A number that reads back below the floor right
		-- after we set it is being re-replicated, which means the server owns it
		-- and no amount of local writing will change the car. Four misses is not
		-- a race condition, it is a mirror - stop lying to the user about it.
		if wrote and (f.kind == "attr" or f.kind == "value") then
			local now
			if f.kind == "value" then
				now = f.inst.Parent and f.inst.Value or nil
			else
				now = f.inst:GetAttribute(f.name)
			end
			if type(now) == "number" and now < f.max then
				f.miss = (f.miss or 0) + 1
				if f.miss >= 4 and not f.mirrored then
					f.mirrored = true
					CG.mirrored += 1
					notify("Cold gas", tostring(f.name) .. " is server-owned · boost assist is carrying the effect")
				end
			else
				f.miss = 0
			end
		end
	end
end

-- Boost assist ----------------------------------------------------------------
-- The fallback that can move a car the game's own gas value cannot. It is OFF by
-- default, and deliberately timid, because writing AssemblyLinearVelocity on an
-- assembly the *server* simulates is not a boost - it is a replication round trip
-- per frame, which is how a car game freezes. So:
--
--   * opt-in, never restored into the "on" state by a config from an old build
--   * 15 Hz, not per frame, with a small per-tick delta
--   * only while the local player is the driver and the car is already rolling
--   * a watchdog that measures the speed it actually produced: if two and a half
--     seconds of pushing bought less than 4 studs/s, the server owns the car,
--     the assist switches itself off and says why. No freeze can outlive that.
local ASSIST = {
	on = false, top = 180, accel = 70,
	acc = 0, watchFrom = nil, watchAt = 0, dead = false,
}
TESLA.assist = ASSIST

function CG.set(on)
	on = on and true or false
	if on == CG.on then return end
	CG.on = on
	if CG.conn then CG.conn:Disconnect(); CG.conn = nil end
	if not on then
		CG.status = "off"
		CG.live = {}
		return
	end
	CG.scan()
	CG.scanAt = os.clock()
	CG.conn = RunService.Heartbeat:Connect(function(dt)
		if ASSIST.on and not ASSIST.dead then
			ASSIST.acc += dt
			if ASSIST.acc >= 1 / 15 then
				local step = ASSIST.acc
				ASSIST.acc = 0
				local seat, model, root = TESLA.vehicle()
				local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
				-- driver only: a passenger cannot drive, and writing velocity from
				-- a seat you do not control is the fastest way to fight physics
				if root and model and seat and hum and seat.Occupant == hum then
					local look = root.CFrame.LookVector
					local v = root.AssemblyLinearVelocity
					local fwd = v:Dot(look)
					if fwd > 8 and fwd < ASSIST.top - 2 then
						local add = math.min(ASSIST.top - fwd, ASSIST.accel * step)
						local ok = pcall(function() root.AssemblyLinearVelocity = v + look * add end)
						if not ok then
							ASSIST.dead = true
							ASSIST.on = false
						else
							local now = os.clock()
							if not ASSIST.watchFrom then
								ASSIST.watchFrom, ASSIST.watchAt = fwd, now
							elseif now - ASSIST.watchAt > 2.5 then
								if fwd - ASSIST.watchFrom < 4 then
									ASSIST.dead = true
									ASSIST.on = false
									notify("Cold gas", "assist cannot move this car · server-owned. Disabled.", "bad")
								else
									ASSIST.watchFrom, ASSIST.watchAt = fwd, now
								end
							end
						end
					else
						ASSIST.watchFrom = nil -- coasting or at the ceiling: not our window
					end
				end
			end
		end

		CG.acc += dt
		-- twice a second: a bar that drains over seconds does not need more, and
		-- every write here is a replicated property change
		if CG.acc < 0.5 then return end
		CG.acc = 0
		-- A car with no gas value at all used to rescan five times a second for as
		-- long as the toggle was on. That is a full descendant walk of the model,
		-- the character and the backpack, five times a second, forever.
		local seatNow = TESLA.seat()
		local stale = seatNow ~= CG.seat
		local idle = #CG.live == 0 and (os.clock() - (CG.scanAt or 0)) > 2.5
		if stale or idle then
			CG.scan()
			CG.scanAt = os.clock()
		end
		CG.apply()
	end)
end

-- What the page shows: how many values we are holding, and whether any of them
-- turned out to be a mirror the server keeps overwriting.
function CG.summary()
	if not CG.on then return "off" end
	if #CG.live == 0 then return CG.status end
	local mirrored = 0
	for _, f in ipairs(CG.live) do
		if f.mirrored then mirrored = mirrored + 1 end
	end
	local head = string.format("%d value%s · %s", #CG.live, #CG.live == 1 and "" or "s", tostring(CG.live[1].name))
	if mirrored > 0 then
		return head .. (ASSIST.on and " · server-owned, assist on" or " · server-owned")
	end
	return head
end

---------------------------------------------------------------- auto-pilot --

local AP = {
	enabled = false, -- listening for the middle click
	active = false,  -- driving
	picking = false, -- camera preview is up
	dest = nil,
	base = nil,
	height = 0,
	stopRadius = 10,
	power = 1,
	invertSteer = false,
	method = "Seat inputs",
	useHeight = false,
	status = "no destination",
	conn = nil,
	cam = nil,
	savedCam = nil,
	part = nil,
	overlay = nil,
	onHeight = nil, -- page hooks in here so the slider follows the wheel
}
TESLA.auto = AP

local function pickPoint()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local m = UserInputService:GetMouseLocation()
	local ray = cam:ViewportPointToRay(m.X, m.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	if LP.Character then ignore[#ignore + 1] = LP.Character end
	local _, model = TESLA.vehicle()
	if model then ignore[#ignore + 1] = model end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
	return hit and hit.Position or nil
end

-- The preview never takes the camera ------------------------------------------
-- It used to park a scriptable Camera over the destination so the spot could be
-- seen from above. Two things made that a bad trade: the game's camera module
-- detaches from a camera it did not create, and if it destroys the old one there
-- is nothing left to hand the view back to - which is exactly the "camera is
-- stuck at one spot while the car drives off" report. The destination is shown in
-- the world instead: a tag on it, and a beam from the ground up to it, so the
-- height the slider sets is legible without touching anybody's view.
local function beamUpdate()
	local b = AP.beam
	if not b then return end
	if not (AP.base and AP.dest) then
		b.Transparency = 1
		return
	end
	local h = math.max(AP.dest.Y - AP.base.Y, 0.2)
	b.Size = Vector3.new(0.35, h, 0.35)
	b.Position = Vector3.new(AP.dest.X, AP.base.Y + h / 2, AP.dest.Z)
	b.Transparency = 0.45
end

local function refreshPreview()
	if AP.part then pcall(function() AP.part.Position = AP.dest end) end
	beamUpdate()
	local o = AP.overlay
	if o and o.info then
		local _, _, root = TESLA.vehicle()
		local away = root and math.floor((AP.dest - root.Position).Magnitude + 0.5) or 0
		o.info.Text = string.format("%dm up · %dm away · scroll to raise", math.floor(AP.height + 0.5), away)
	end
end

local function buildOverlay()
	if AP.overlay and AP.overlay.card then AP.overlay.card:Destroy() end
	local card = new("CanvasGroup", {
		Name = "AetherDestination", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(352, 64), BackgroundColor3 = T.bg, BackgroundTransparency = 0.03,
		BorderSizePixel = 0, ZIndex = 60, Parent = A.screen,
	})
	corner(card, 10)
	stroke(card, T.stroke, 0.25)
	label({ Text = "Destination", Font = A.FONT.bold, TextSize = 12, Position = UDim2.fromOffset(14, 9), Size = UDim2.fromOffset(180, 14), Parent = card })
	local info = label({ Text = "", TextColor3 = T.muted, TextSize = 10, Position = UDim2.fromOffset(14, 26), Size = UDim2.fromOffset(210, 26), Parent = card })

	local function mkbtn(text, xoff, color, cb)
		local b = new("TextButton", {
			Text = text, Font = A.FONT.bold, TextSize = 11, TextColor3 = T.text, BackgroundColor3 = color,
			AutoButtonColor = false, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xoff, 0.5, 0), Size = UDim2.fromOffset(70, 26), Parent = card,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }) })
		b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.accent }) end)
		b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = color }) end)
		b.MouseButton1Click:Connect(function() A.sfx("tap", 0.8); cb() end)
	end
	mkbtn("Drive", -92, T.accent, function() AP.confirm() end)
	mkbtn("Cancel", -14, T.stroke, function() AP.cancel() end)

	AP.overlay = { card = card, info = info }
	refreshPreview()
end

local function teardownPreview()
	if AP.overlay and AP.overlay.card then AP.overlay.card:Destroy() end
	AP.overlay = nil
	if AP.part then pcall(function() AP.part:Destroy() end) end
	AP.part = nil
	if AP.beam then pcall(function() AP.beam:Destroy() end) end
	AP.beam = nil
	if AP.cam then pcall(function() AP.cam:Destroy() end) end
	AP.cam = nil
	-- safety net only: an older build could leave a scriptable camera in place, and
	-- the view has to come back to the game's own camera if that ever happens
	if AP.savedCam and AP.savedCam.Parent and AP.savedCam:IsA("Camera")
		and workspace.CurrentCamera ~= AP.savedCam then
		pcall(function() workspace.CurrentCamera = AP.savedCam end)
	end
	AP.savedCam = nil
	AP.picking = false
end

function AP.setHeight(h)
	h = math.clamp(tonumber(h) or 0, -30, 240)
	AP.height = h
	if AP.base then AP.dest = AP.base + Vector3.new(0, h, 0) end
	refreshPreview()
	if AP.onHeight then pcall(AP.onHeight, h) end
end

function AP.pick(at)
	if not A.loadingDone then return end
	if AP.picking then AP.cancel() end -- re-picking replaces the preview, never stacks one
	if AP.active then AP.stop("re-placing destination") end
	local point = at or pickPoint()
	if not point then
		return notify("Auto-pilot", "aim at the ground and middle-click", "bad")
	end
	AP.base = point
	AP.picking = true
	-- the view is never reassigned: the game's camera stays the game's camera, so
	-- the moment Drive is pressed it keeps working as a chase camera
	AP.savedCam = workspace.CurrentCamera

	local part = new("Part", {
		Name = "AetherDestination", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, Transparency = 1, Size = Vector3.new(1, 1, 1), Parent = workspace,
	})
	AP.part = part
	local beam = new("Part", {
		Name = "AetherDestinationBeam", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
		CastShadow = false, Material = Enum.Material.Neon,
		Color = T.accent, Transparency = 0.45, Size = Vector3.new(0.35, 1, 0.35), Parent = workspace,
	})
	AP.beam = beam
	local bb = new("BillboardGui", {
		Name = "tag", Adornee = part, AlwaysOnTop = true, Size = UDim2.fromOffset(170, 22),
		StudsOffset = Vector3.new(0, 2.2, 0), Parent = part,
	})
	label({ Text = "destination", Font = A.FONT.bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.35, Size = UDim2.fromScale(1, 1), Parent = bb })

	AP.setHeight(AP.height or 0)
	buildOverlay()
	refreshPreview()
	A.sfx("open")
end

function AP.cancel()
	if not AP.picking then return end
	teardownPreview()
	AP.dest = nil
	AP.status = "no destination"
	A.sfx("close")
end

-- The drive loop. One step per frame, deliberately not a controller with
-- integrators: a car that is steered by its own seat wants an input vector, and
-- anything cleverer than "point at it, throttle by how far it is" fights the
-- chassis instead of driving it.
local function driveStep()
	local seat, model, root = TESLA.vehicle()
	if not (seat and model and root) then return AP.stop("left the vehicle") end
	local pos = root.Position
	local target = AP.dest
	local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	local dist = flat.Magnitude
	AP.status = string.format("%dm to go", math.floor(dist + 0.5))

	if AP.useHeight then
		if (target - pos).Magnitude <= AP.stopRadius then
			AP.stop("arrived")
			return notify("Auto-pilot", "arrived", "good")
		end
	elseif dist <= AP.stopRadius then
		AP.stop("arrived")
		return notify("Auto-pilot", "arrived", "good")
	end
	if dist < 1e-3 then return end

	if AP.method == "Seat inputs" and seat:IsA("VehicleSeat") then
		local look = root.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 0.01 then return end
		look = look.Unit
		local want = flat.Unit
		local cross = look:Cross(want).Y
		local steer = math.clamp(-cross * 2.4, -1, 1)
		if AP.invertSteer then steer = -steer end
		local throttle = math.clamp(AP.power * math.clamp(dist / 45, 0.45, 1), 0, 1)
		-- pointing away and close: back up rather than loop around the block
		if look:Dot(want) < -0.35 and dist < 30 then throttle = -throttle * 0.7 end
		pcall(function()
			seat.ThrottleFloat = throttle
			seat.SteerFloat = steer
		end)
	else
		-- custom chassis: push the assembly, let its own suspension hold it up
		local v = root.AssemblyLinearVelocity
		local flatV = flat.Unit * (AP.power * math.clamp(90 * dist / 45, 25, 90))
		local y = v.Y
		if AP.useHeight then y = math.clamp((target.Y - pos.Y) * 2, -40, 40) end
		pcall(function() root.AssemblyLinearVelocity = Vector3.new(flatV.X, y, flatV.Z) end)
	end
end

local function beginDrive()
	if not AP.dest then return end
	AP.active = true
	AP.status = "driving"
	if AP.conn then AP.conn:Disconnect() end
	AP.conn = RunService.Heartbeat:Connect(driveStep)
	A.sfx("on")
end
TESLA.beginDrive = beginDrive

function AP.confirm()
	if not AP.picking or not AP.dest then return end
	teardownPreview()
	beginDrive()
end

function AP.stop(why)
	if AP.conn then AP.conn:Disconnect(); AP.conn = nil end
	local seat = TESLA.seat()
	if seat then
		pcall(function()
			if seat:IsA("VehicleSeat") then seat.ThrottleFloat = 0; seat.SteerFloat = 0 end
		end)
	end
	AP.active = false
	AP.status = why or "stopped"
	if why and why ~= "arrived" then A.sfx("off") end
end

function AP.toggle()
	if AP.picking then return AP.cancel() end
	if AP.active then return AP.stop("stopped") end
	if not AP.dest then
		return notify("Auto-pilot", "middle-click a location first", "bad")
	end
	beginDrive()
end

------------------------------------------------------------------ spots --

local function spots()
	local e = A.extra or {}
	if type(e.teslaSpots) ~= "table" then e.teslaSpots = {} end
	return e.teslaSpots
end
TESLA.spots = spots

function TESLA.saveSpot()
	if not AP.dest then return nil, "pick a destination first" end
	local list = spots()
	local rec = {
		name = "Spot " .. tostring(#list + 1),
		x = math.floor(AP.dest.X + 0.5), y = math.floor(AP.dest.Y + 0.5), z = math.floor(AP.dest.Z + 0.5),
	}
	list[#list + 1] = rec
	if A.touch then A.touch() end
	return rec.name
end

function TESLA.clearSpots()
	local e = A.extra or {}
	e.teslaSpots = {}
	if A.touch then A.touch() end
end

function TESLA.driveTo(rec)
	if not rec then return end
	AP.base = Vector3.new(rec.x, rec.y, rec.z)
	AP.dest = AP.base
	AP.setHeight(0)
	beginDrive()
end

onCleanup(function() teardownPreview() end)

----------------------------------------------------------- attribute map --

-- The numbers that actually drive the car. A gas poller cannot raise a top speed
-- that lives in an attribute, because the speed is computed from that number - so
-- the attribute is the thing to hand the user. They are all named for a
-- programmer (TopSpeed, NitroMul, MaxThrust), which is why this section exists:
-- find them, rename them into English, keep the value they had when it was found,
-- and let the page put a box and a reset next to each one.
local ATTR = { list = {}, mappedAt = 0 }
TESLA.attrs = ATTR

local function flat(name)
	return tostring(name):lower():gsub("[%s_%-%./:]", "")
end

function ATTR.fmt(v)
	if type(v) ~= "number" then return tostring(v) end
	if v == math.floor(v) and math.abs(v) < 1e15 then return string.format("%d", v) end
	return string.format("%.4g", v)
end

-- keyword -> label. Specific before generic: "maxspeed" has to win over "speed".
local NAME_WORDS = {
	{ "maxspeed", "Max speed" }, { "topspeed", "Top speed" }, { "vmax", "Max speed" },
	{ "maxvelocity", "Max velocity" }, { "speed", "Speed" }, { "velocity", "Velocity" },
	{ "acceleration", "Acceleration" }, { "accel", "Acceleration" },
	{ "thrust", "Thrust" }, { "torque", "Torque" }, { "engine", "Engine power" },
	{ "power", "Power" }, { "force", "Force" },
	{ "gravity", "Gravity" }, { "grav", "Gravity" }, { "weight", "Weight" },
	{ "mass", "Mass" }, { "density", "Density" },
	{ "nitromul", "Nitro multiplier" }, { "nitro", "Nitro" }, { "turbo", "Turbo" },
	{ "boost", "Boost" }, { "overdrive", "Overdrive" }, { "nos", "NOS" },
	{ "steering", "Steering" }, { "steer", "Steering" }, { "handling", "Handling" },
	{ "turn", "Turning" }, { "friction", "Friction" }, { "grip", "Grip" },
	{ "drag", "Drag" }, { "damping", "Damping" }, { "suspension", "Suspension" },
	{ "spring", "Spring" }, { "downforce", "Downforce" }, { "lift", "Lift" },
	{ "jump", "Jump power" }, { "hover", "Hover" }, { "fly", "Fly" },
	{ "coldgas", "Cold gas" }, { "gas", "Gas" }, { "fuel", "Fuel" },
	{ "charge", "Charge" }, { "energy", "Energy" }, { "battery", "Battery" },
	{ "health", "Health" },
}

-- which shelf a number belongs on, and in what order the rows appear
local GROUPS = {
	{ id = "speed", rank = 1, words = { "speed", "vmax", "velocity", "vel", "spd" } },
	{ id = "accel", rank = 2, words = { "accel", "thrust", "torque", "power", "force", "engine" } },
	{ id = "physics", rank = 3, words = { "gravity", "grav", "mass", "weight", "density", "downforce", "lift" } },
	{ id = "steer", rank = 4, words = { "steer", "turn", "handling" } },
	{ id = "grip", rank = 5, words = { "friction", "grip", "drag", "damping", "suspension", "spring" } },
	{ id = "boost", rank = 6, words = { "boost", "nitro", "turbo", "nos", "overdrive" } },
	{ id = "fuel", rank = 7, words = { "gas", "fuel", "charge", "energy", "battery" } },
}

-- a name nothing matched is still shown, just last: the car found something, and
-- hiding it because we did not recognise the word is the worse mistake
local RANK_OTHER = 9

local function groupOf(name)
	local n = flat(name)
	for _, g in ipairs(GROUPS) do
		for _, w in ipairs(g.words) do
			if n:find(w, 1, true) then return g.id, g.rank end
		end
	end
	return "other", RANK_OTHER
end

function ATTR.label(name)
	local n = flat(name)
	for _, pair in ipairs(NAME_WORDS) do
		if n:find(pair[1], 1, true) then return pair[2] end
	end
	-- CamelCase -> "Camel case", the generic fallback
	local words = tostring(name):gsub("(%l)(%u)", "%1 %2"):gsub("_", " "):gsub("%s+", " ")
	words = words:gsub("^%l", string.upper)
	return words
end

function ATTR.read(e)
	if e.kind == "attr" then
		local ok, v = pcall(e.inst.GetAttribute, e.inst, e.name)
		return ok and v or nil
	elseif e.kind == "value" then
		local ok, v = pcall(function() return e.inst.Value end)
		return ok and v or nil
	elseif e.kind == "gravity" then
		return workspace.Gravity
	end
end

-- Write, then read back. A number the server keeps re-sending downward is not
-- ours to hold, and saying so beats a box that silently snaps back.
function ATTR.set(e, value)
	local v = tonumber(value)
	if not v then return false, "not a number" end
	local ok
	if e.kind == "attr" then
		ok = pcall(e.inst.SetAttribute, e.inst, e.name, v)
	elseif e.kind == "value" then
		ok = pcall(function() e.inst.Value = v end)
	elseif e.kind == "gravity" then
		ok = pcall(function() workspace.Gravity = v end)
	else
		return false, "this one cannot be written"
	end
	local now = ATTR.read(e)
	if type(now) == "number" then e.value = now end
	if not ok then return false, "the game refused the write" end
	if type(now) == "number" and math.abs(now - v) > 1e-4 then
		return false, "server-owned · reads back as " .. ATTR.fmt(now)
	end
	return true
end

function ATTR.reset(e)
	return ATTR.set(e, e.base)
end

-- One walk, same budget rule as the gas scan: a car built like a map does not get
-- walked forever. Attributes first on the model and the seat, then every
-- descendant that carries one, then NumberValue/IntValue children.
function ATTR.map()
	local out, seen = {}, {}

	local function push(inst, kind, name, value, scope)
		if type(value) ~= "number" then return end
		local id = tostring(scope) .. "|" .. tostring(name) .. "|" .. kind
		if seen[id] then return end
		seen[id] = true
		local group, rank = groupOf(name)
		out[#out + 1] = {
			inst = inst, kind = kind, name = name, scope = scope,
			value = value, base = value, group = group, rank = rank,
			label = ATTR.label(name),
		}
	end

	local function attrs(inst, scope)
		if not inst then return end
		local ok, a = pcall(inst.GetAttributes, inst)
		if not (ok and type(a) == "table") then return end
		for k, v in pairs(a) do
			if type(v) == "number" then push(inst, "attr", k, v, scope) end
		end
	end

	local seat, model = TESLA.vehicle()
	if model then
		attrs(model, "car")
		attrs(seat, "seat")
		local budget = 600
		for _, d in ipairs(model:GetDescendants()) do
			budget -= 1
			if budget <= 0 then break end
			attrs(d, "car")
			if d:IsA("NumberValue") or d:IsA("IntValue") then
				push(d, "value", d.Name, d.Value, "car")
			end
		end
		attrs(LP.Character, "player")
	end
	-- the world number a flying car is most likely fighting
	push(workspace, "gravity", "Gravity", workspace.Gravity, "world")

	table.sort(out, function(a, b)
		if a.rank ~= b.rank then return a.rank < b.rank end
		if a.label ~= b.label then return a.label < b.label end
		return tostring(a.name) < tostring(b.name)
	end)
	while #out > 24 do table.remove(out) end

	ATTR.list = out
	ATTR.mappedAt = os.clock()
	return out
end

------------------------------------------------------------------ input --

-- Middle click is the picker. It only fires while the toggle is on, so the same
-- button keeps working as the game's own camera when the module is off.
local inputConn = UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.UserInputType == Enum.UserInputType.MouseButton3 and AP.enabled and not AP.picking then
		AP.pick()
	elseif AP.picking then
		if i.KeyCode == Enum.KeyCode.Escape then
			AP.cancel()
		elseif i.KeyCode == Enum.KeyCode.Return or i.KeyCode == Enum.KeyCode.KeypadEnter then
			AP.confirm()
		end
	end
end)

-- the wheel raises the destination while the preview is up: "pick the height"
local wheelConn = UserInputService.InputChanged:Connect(function(i)
	if not AP.picking then return end
	if i.UserInputType == Enum.UserInputType.MouseWheel then
		AP.setHeight(AP.height + i.Position.Z * 2)
	end
end)

onCleanup(function()
	inputConn:Disconnect()
	wheelConn:Disconnect()
	CG.set(false)
	teardownPreview()
	AP.stop("unloaded")
end)
