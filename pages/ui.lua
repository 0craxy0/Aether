local A = ...
local new, tween = A.new, A.tween
local T, accentLinks, KB, EL = A.T, A.accentLinks, A.KB, A.EL
local window, shadow, uiScales = A.window, A.shadow, A.uiScales
local UserInputService, onCleanup = A.UserInputService, A.onCleanup
local toggle, slider, button = A.toggle, A.slider, A.button

local pUI = A.makePage("UI", 6)
local sUI = pUI.section("Keybind list", 1)
toggle(sUI, "Show keybind list", true, function(v) A.kbList.Visible = v end)

-- rescaling (corner handles, X and Y independent) ---------------
local RS = {
	scaleOn = true, vw = A.W, vh = A.H, minW = 420, minH = 320, maxW = 960, maxH = 720,
	defW = A.W, defH = A.H, handles = {}, drag = nil,
}

-- A.W / A.H hold the logical (pre-UIScale) size; the config menus and the show/hide handler read them
local function rsApplySize(nw, nh)
	RS.vw, RS.vh = nw, nh
	local sc = 1
	if RS.scaleOn then sc = math.clamp(math.min(nw / RS.defW, nh / RS.defH), 0.5, 3) end
	for _, u in ipairs(uiScales) do u.Scale = sc end
	A.W, A.H = nw / sc, nh / sc
	window.Size = UDim2.fromOffset(A.W, A.H)
	shadow.Size = UDim2.fromOffset(RS.vw + 44, RS.vh + 44)
end
A.RS, A.rsApplySize = RS, rsApplySize

local rsCorners = {
	{ -1, -1, Vector2.new(0, 0) }, { 1, -1, Vector2.new(1, 0) },
	{ -1, 1, Vector2.new(0, 1) }, { 1, 1, Vector2.new(1, 1) },
}
for _, c in ipairs(rsCorners) do
	local sx, sy, anchor = c[1], c[2], c[3]
	local handle = new("TextButton", {
		Text = "", BackgroundTransparency = 1, AutoButtonColor = false, Visible = false,
		AnchorPoint = anchor, Position = UDim2.fromScale(anchor.X, anchor.Y),
		Size = UDim2.fromOffset(18, 18), ZIndex = 20, Parent = window,
	})
	local dot = new("Frame", {
		AnchorPoint = anchor, Position = UDim2.new(anchor.X, -sx * 5, anchor.Y, -sy * 5),
		Size = UDim2.fromOffset(6, 6), BackgroundColor3 = T.accent, BorderSizePixel = 0,
		ZIndex = 21, Parent = handle,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	accentLinks[#accentLinks + 1] = { obj = dot, kind = "fill" }
	handle.MouseEnter:Connect(function() tween(dot, 0.12, { Size = UDim2.fromOffset(10, 10) }) end)
	handle.MouseLeave:Connect(function()
		if not RS.drag then tween(dot, 0.12, { Size = UDim2.fromOffset(6, 6) }) end
	end)
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			RS.drag = { sx = sx, sy = sy, start = i.Position, w = RS.vw, h = RS.vh, pos = window.Position }
		end
	end)
	RS.handles[#RS.handles + 1] = handle
end

local rsMove = UserInputService.InputChanged:Connect(function(i)
	local d = RS.drag
	if not d then return end
	if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = i.Position - d.start
	local nw = math.floor(math.clamp(d.w + d.sx * delta.X, RS.minW, RS.maxW))
	local nh = math.floor(math.clamp(d.h + d.sy * delta.Y, RS.minH, RS.maxH))
	rsApplySize(nw, nh)
	-- keep the opposite corner pinned (window is centre-anchored)
	window.Position = A.clampPos(UDim2.new(d.pos.X.Scale, d.pos.X.Offset + d.sx * (nw - d.w) / 2, d.pos.Y.Scale, d.pos.Y.Offset + d.sy * (nh - d.h) / 2), Vector2.new(nw, nh))
	shadow.Position = window.Position
end)
local rsEnd = UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		RS.drag = nil
	end
end)
onCleanup(function() rsMove:Disconnect(); rsEnd:Disconnect() end)

local sUI2 = pUI.section("Window", 2)
toggle(sUI2, "UI rescaling", false, function(v)
	RS.drag = nil
	for _, h in ipairs(RS.handles) do h.Visible = v end
end)
toggle(sUI2, "Scale UI contents", true, function(v)
	RS.scaleOn = v
	rsApplySize(RS.vw, RS.vh)
end)
button(sUI2, "Reset UI size", "RESET", function() rsApplySize(RS.defW, RS.defH) end)
toggle(sUI2, "Apply sliders on release", true, function(v) KB.opts.sliderRelease = v end)

local sUI3 = pUI.section("Window physics", 3)
toggle(sUI3, "Rubber band edges", true, function(v) EL.rubber = v end)
slider(sUI3, "Rubber band size", 10, 200, 56, function(v) EL.margin = v end)
toggle(sUI3, "Throw physics", true, function(v) EL.physics = v end)
slider(sUI3, "Throw friction", 10, 100, 70, function(v) EL.fr = v / 50 end)
slider(sUI3, "Bounciness", 0, 95, 72, function(v) EL.rest = v / 100 end)

-- the Extras section is shared: tail/extras.lua and tail/glass.lua add their rows to it
A.sUI4 = pUI.section("Extras", 4)

