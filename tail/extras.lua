local A = ...
local new, tween, toggle = A.new, A.tween, A.toggle
local FONT, ANIM, UI = A.FONT, A.ANIM, A.UI
local screen, window = A.screen, A.window
local RunService, onCleanup = A.RunService, A.onCleanup

-- easter egg: a window corner meets a screen corner -------------
local EE = { on = true, armed = true, last = 0, tol = 12, sound = "rbxasset://sounds/victory.wav" }
local layer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 100, Parent = screen })
local COLORS = {
	Color3.fromRGB(255, 92, 122), Color3.fromRGB(61, 220, 151), Color3.fromRGB(78, 168, 255),
	Color3.fromRGB(255, 190, 60), Color3.fromRGB(124, 92, 255), Color3.fromRGB(255, 255, 255),
}

local function cornerHit(tol)
	local target = window
	if not window.Visible then
		if not UI.active then return nil end
		target = UI.active.frame
	end
	local vp = screen.AbsoluteSize
	local p, s = target.AbsolutePosition, target.AbsoluteSize
	local left, right = p.X <= tol, p.X + s.X >= vp.X - tol
	local top, bottom = p.Y <= tol, p.Y + s.Y >= vp.Y - tol
	if left and top then return 0, 0 end
	if right and top then return vp.X, 0 end
	if left and bottom then return 0, vp.Y end
	if right and bottom then return vp.X, vp.Y end
	return nil
end

local function burst(ox, oy)
	local vp = screen.AbsoluteSize
	local base = math.atan2(vp.Y / 2 - oy, vp.X / 2 - ox)
	local pieces = {}
	for i = 1, 100 do
		local ang = base + (math.random() - 0.5) * 1.7
		local sp = 500 + math.random() * 1000
		local f = new("Frame", {
			Size = UDim2.fromOffset(math.random(6, 11), math.random(4, 8)), AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(ox, oy), BackgroundColor3 = COLORS[math.random(#COLORS)],
			BorderSizePixel = 0, Rotation = math.random(0, 360), ZIndex = 101, Parent = layer,
		})
		pieces[i] = { f = f, x = ox, y = oy, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp, spin = (math.random() - 0.5) * 900, life = 0, max = 2.4 + math.random() * 1.2 }
	end
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		dt = math.min(dt, 1 / 30)
		local alive = 0
		for _, p in ipairs(pieces) do
			if p.f.Parent then
				p.life += dt
				if p.life >= p.max then
					p.f:Destroy()
				else
					alive += 1
					p.vy += 900 * dt
					local drag = math.exp(-1.6 * dt)
					p.vx *= drag
					p.vy *= drag
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.f.Position = UDim2.fromOffset(p.x, p.y)
					p.f.Rotation = p.f.Rotation + p.spin * dt
					local rem = p.max - p.life
					if rem < 0.6 then p.f.BackgroundTransparency = 1 - rem / 0.6 end
				end
			end
		end
		if alive == 0 then conn:Disconnect() end
	end)
end

local function banner()
	local t = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.new(1, 0, 0, 90),
		BackgroundTransparency = 1, Font = FONT.bold, Text = "YIPPEE!!!! MLGGGG!! SIRMEME I KNOW YOU CAN PROBABLY SEE THIS!!", TextSize = 8,
		TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, TextTransparency = 1, ZIndex = 102, Parent = layer,
	})
	tween(t, 0.45, { TextSize = 54, TextTransparency = 0 }, Enum.EasingStyle.Back)
	task.spawn(function()
		local t0 = os.clock()
		while t.Parent and os.clock() - t0 < 2.4 do
			t.TextColor3 = Color3.fromHSV((os.clock() * 1.5) % 1, 0.8, 1)
			t.Rotation = math.sin(os.clock() * 14) * 2
			RunService.Heartbeat:Wait()
		end
		if t.Parent then
			tween(t, 0.4, { TextTransparency = 1, TextStrokeTransparency = 1 })
			task.wait(0.4)
			t:Destroy()
		end
	end)
end

local function sfx()
	local s = new("Sound", { SoundId = EE.sound, Volume = 1, Parent = screen })
	pcall(function() s:Play() end)
	task.delay(6, function()
		if s.Parent then s:Destroy() end
	end)
end

local eeConn = RunService.Heartbeat:Connect(function()
	if not EE.on then return end
	local cx, cy = cornerHit(EE.tol)
	if cx then
		if EE.armed and os.clock() - EE.last > 1.5 then
			EE.armed = false
			EE.last = os.clock()
			burst(cx, cy)
			banner()
			sfx()
		end
	elseif not cornerHit(EE.tol * 3) then
		EE.armed = true
	end
end)
onCleanup(function() eeConn:Disconnect(); layer:Destroy() end)

toggle(A.sUI4, "Corner easter egg", true, function(v) EE.on = v end)
toggle(A.sUI4, "Exaggerated animations", true, function(v) ANIM.on = v end)

