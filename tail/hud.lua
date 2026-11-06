local A = ...
local new, tween, corner, stroke, label = A.new, A.tween, A.corner, A.stroke, A.label
local T, FONT, toggle = A.T, A.FONT, A.toggle
local screen, Players = A.screen, A.Players
local UserInputService, RunService, onCleanup = A.UserInputService, A.RunService, A.onCleanup

-- Stats HUD · frames per second, round trip and head count in one small pill ----
-- Sampled four times a second. Reading the Stats service on every frame costs
-- more than the numbers are worth, and this is a readout, not a profiler.
local H = { on = false, fps = 0, ping = -1, count = 0 }
A.HUD = H

local W, HGT = 190, 30

local pill = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -14),
	Size = UDim2.fromOffset(W, HGT), BackgroundColor3 = T.panel,
	BackgroundTransparency = 0.12, GroupTransparency = 1, Visible = false, Parent = screen,
})
corner(pill, 9)
stroke(pill, T.stroke, 0.4)
A.maskGuis[#A.maskGuis + 1] = pill -- ESP must not draw across the readout either

local dot = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 13, 0.5, 0),
	Size = UDim2.fromOffset(6, 6), BackgroundColor3 = T.good, BorderSizePixel = 0, Parent = pill,
}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

local fpsL = label({ Text = "— fps", Font = FONT.med, TextSize = 11, Position = UDim2.fromOffset(25, 0), Size = UDim2.new(0, 58, 1, 0), Parent = pill })
local pingL = label({ Text = "— ms", TextSize = 11, TextColor3 = T.muted, Position = UDim2.fromOffset(87, 0), Size = UDim2.new(0, 52, 1, 0), Parent = pill })
local plrL = label({ Text = "— plr", TextSize = 11, TextColor3 = T.muted, Position = UDim2.fromOffset(141, 0), Size = UDim2.new(0, 44, 1, 0), Parent = pill })

-- drag: an input surface over the whole pill, offsets only, clamped to the screen
local grip = new("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromScale(1, 1), Parent = pill })
local dragging, dragFrom, dragPos

grip.InputBegan:Connect(function(i)
	local t = i.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	dragging = true
	dragFrom = i.Position
	dragPos = pill.Position
	tween(pill, 0.15, { BackgroundTransparency = 0.02 })
end)

local moveConn = UserInputService.InputChanged:Connect(function(i)
	if not dragging then return end
	local t = i.UserInputType
	if t ~= Enum.UserInputType.MouseMovement and t ~= Enum.UserInputType.Touch then return end
	local d = i.Position - dragFrom
	local vp = screen.AbsoluteSize
	local x = math.clamp(dragPos.X.Offset + d.X, 0, math.max(vp.X - W, 0))
	local y = math.clamp(dragPos.Y.Offset + d.Y, -math.max(vp.Y - HGT, 0), 0)
	pill.Position = UDim2.new(0, x, 1, y)
end)

local endConn = UserInputService.InputEnded:Connect(function(i)
	if not dragging then return end
	local t = i.UserInputType
	if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
	dragging = false
	tween(pill, 0.2, { BackgroundTransparency = 0.12 })
end)

local statItem
pcall(function()
	statItem = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
end)

local frames, acc = 0, 0
local sampleConn = RunService.Heartbeat:Connect(function(dt)
	frames += 1
	acc += dt
	if acc < 0.25 then return end
	if not H.on then
		frames, acc = 0, 0
		return
	end
	H.fps = math.floor(frames / acc + 0.5)
	frames, acc = 0, 0

	if statItem then
		local ok, v = pcall(function() return statItem:GetValue() end)
		H.ping = (ok and type(v) == "number") and math.floor(v + 0.5) or -1
	end
	H.count = #Players:GetPlayers()

	local col = H.fps >= 50 and T.good or H.fps >= 30 and T.warn or T.bad
	fpsL.Text = H.fps .. " fps"
	fpsL.TextColor3 = col
	dot.BackgroundColor3 = col
	pingL.Text = H.ping >= 0 and (H.ping .. " ms") or "— ms"
	-- a round trip over 150ms is the number worth looking at, not just the frame rate
	pingL.TextColor3 = (H.ping >= 0 and H.ping > 150) and T.warn or T.muted
	plrL.Text = H.count .. " plr"
end)

function H.set(on)
	H.on = on and true or false
	if H.on then
		pill.Visible = true
		tween(pill, 0.4, { GroupTransparency = 0 }, Enum.EasingStyle.Back)
	else
		tween(pill, 0.2, { GroupTransparency = 1 })
		task.delay(0.2, function()
			if not H.on then pill.Visible = false end
		end)
	end
end

onCleanup(function()
	sampleConn:Disconnect()
	moveConn:Disconnect()
	endConn:Disconnect()
	pill:Destroy()
end)

toggle(A.sUI4, "Stats HUD", false, H.set)

A.stage("hud done")
