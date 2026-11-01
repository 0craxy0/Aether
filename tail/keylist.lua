local A = ...
local new, tween, corner, stroke, label = A.new, A.tween, A.corner, A.stroke, A.label
local T, FONT, KB, accentLinks = A.T, A.FONT, A.KB, A.accentLinks
local screen, maskGuis, keybinds = A.screen, A.maskGuis, A.keybinds
local RunService, onCleanup = A.RunService, A.onCleanup

-- keybind list overlay -----------------------------------------
local kbList = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(190, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = screen,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
})
A.kbList = kbList
A.depth.register(kbList, 0.55)
maskGuis[#maskGuis + 1] = kbList

local kbRows = {}

local function kbKey(mod)
	local bind = KB.binds[mod]
	if bind then
		for k, n in pairs(keybinds) do
			if n == bind then return k end
		end
	end
	return "—"
end

local function kbAdd(mod)
	if kbRows[mod] then return end
	local wrap = new("Frame", {
		Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
		LayoutOrder = KB.index[mod] or 99, Parent = kbList,
	})
	local row = new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(-24, 0), GroupTransparency = 1,
		BackgroundColor3 = T.panel, BackgroundTransparency = 0.1, BorderSizePixel = 0, Parent = wrap,
	})
	corner(row, 7)
	stroke(row, T.stroke, 0.35)
	local bar = new("Frame", { Size = UDim2.fromOffset(2, 12), Position = UDim2.fromOffset(0, 7), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = row }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	accentLinks[#accentLinks + 1] = { obj = bar, kind = "fill" }
	label({ Text = mod, Font = FONT.med, TextSize = 12, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -70, 1, 0), Parent = row })
	local box = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.raised, BorderSizePixel = 0, Text = kbKey(mod),
		Font = FONT.bold, TextSize = 10, TextColor3 = T.muted, Parent = row,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 5) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
		new("UIStroke", { Color = T.stroke, Transparency = 0.4, Thickness = 1 }),
	})
	kbRows[mod] = { wrap = wrap, row = row, box = box }
	tween(row, 0.7, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 }, Enum.EasingStyle.Elastic)
end

local function kbRemove(mod)
	local r = kbRows[mod]
	if not r then return end
	kbRows[mod] = nil
	tween(r.row, 0.18, { GroupTransparency = 1, Position = UDim2.fromOffset(-24, 0) })
	task.delay(0.18, function()
		if not r.wrap.Parent then return end
		tween(r.wrap, 0.15, { Size = UDim2.new(1, 0, 0, 0) })
		task.delay(0.15, function() r.wrap:Destroy() end)
	end)
end

KB.onToggle = function(name, v)
	if not KB.index[name] then return end
	if v then kbAdd(name) else kbRemove(name) end
end
-- toggles created before this file loaded (default-on ones) get their rows now
for name in pairs(KB.active) do KB.onToggle(name, true) end

local kbConn = RunService.Heartbeat:Connect(function()
	for mod, r in pairs(kbRows) do
		local k = kbKey(mod)
		if r.box.Text ~= k then r.box.Text = k end
	end
end)
onCleanup(function() kbConn:Disconnect() end)

A.stage("6 keybind overlay done")

