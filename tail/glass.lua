local A = ...
local new, toggle, slider = A.new, A.toggle, A.slider
local T, UI, Lighting = A.T, A.UI, A.Lighting
local window, maskGuis, uiScales = A.window, A.maskGuis, A.uiScales
local RunService, UserInputService, onCleanup = A.RunService, A.UserInputService, A.onCleanup
local sUI4 = A.sUI4

-- glass: translucent panels over a blurred backdrop -------------
local GL = { on = true, blur = 14, alpha = 0.3 }
GL.fx = new("BlurEffect", { Name = "AetherBlur", Size = 0, Parent = Lighting })

local function glassApply()
	for _, g in ipairs(maskGuis) do
		if g:IsA("CanvasGroup") then g.BackgroundTransparency = GL.alpha end
	end
end
glassApply()

local glConn = RunService.Heartbeat:Connect(function()
	-- A.loadingDone gates the whole effect: the panel exists (and its ScreenGui is
	-- disabled) while the loading card is up, and blurring the game behind that
	-- card is not the look anyone asked for
	local shown = A.loadingDone and ((window.Visible and window.GroupTransparency < 0.95)
		or (UI.active ~= nil and UI.active.frame.GroupTransparency < 0.95))
	local want = (GL.on and shown) and GL.blur or 0
	GL.fx.Size = GL.fx.Size + (want - GL.fx.Size) * 0.12
	-- ease, then land: an exponential approach never reaches zero, so turning the
	-- blur off left a fractional blur on the whole screen for the rest of the session
	if math.abs(GL.fx.Size - want) < 0.05 then GL.fx.Size = want end
end)
onCleanup(function() glConn:Disconnect(); GL.fx:Destroy() end)

toggle(sUI4, "Glass blur", true, function(v) GL.on = v end)
slider(sUI4, "Glass blur strength", 0, 40, 14, function(v) GL.blur = v end)
slider(sUI4, "Glass transparency", 0, 90, 30, function(v) GL.alpha = v / 100; glassApply() end)

-- Liquid Glass (beta, off by default) ---------------------------
-- clearer panels, a lit rim that follows the cursor, a soft highlight under it
local LG = { on = false, saved = {}, prevAlpha = 0.3, prevBlur = 14, mx = 0, my = 0, wasShown = false, snap = false }
local wcorner = window:FindFirstChildOfClass("UICorner")
LG.rim = new("Frame", {
	Name = "lgRim", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Active = false, ZIndex = 60, Parent = window,
}, { new("UICorner", { CornerRadius = wcorner and wcorner.CornerRadius or UDim.new(0, 16) }) })
LG.rimStroke = new("UIStroke", { Thickness = 1.5, Color = Color3.new(1, 1, 1), Transparency = 0, Parent = LG.rim })
LG.rimGrad = new("UIGradient", {
	Rotation = 45,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.3, 0.85),
		NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 0.15),
	}),
	Parent = LG.rimStroke,
})
LG.top = new("Frame", {
	Name = "lgTop", Size = UDim2.fromScale(1, 0.3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Active = false, ZIndex = 59, Parent = window,
}, {
	-- same radius as the shell, or the square frame shows past the rounded corner
	new("UICorner", { CornerRadius = wcorner and wcorner.CornerRadius or UDim.new(0, 19) }),
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) }) }),
})
LG.glowHolder = new("Frame", { Name = "lgGlow", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Active = false, ZIndex = 58, Parent = window })
LG.glow = {}
for i = 1, 6 do
	local d = 70 + i * 46
	LG.glow[i] = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(d, d), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.975, BorderSizePixel = 0, Active = false, Parent = LG.glowHolder,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
end

local function isGlassRow(o)
	return o:IsA("Frame") and o.BackgroundTransparency < 1 and (o.BackgroundColor3 == T.raised or o.BackgroundColor3 == T.panel)
end

-- rowAlpha is what rowBase's hover tween returns to, so hovering a row can't undo the glass look
local function setLG(v)
	if v == LG.on then return end
	LG.on = v
	if v then
		LG.prevAlpha, LG.prevBlur = GL.alpha, GL.blur
		GL.alpha, GL.blur = 0.62, 26
		A.rowAlpha.idle, A.rowAlpha.hover = 0.6, 0.45
		glassApply()
		for _, o in ipairs(window:GetDescendants()) do
			if isGlassRow(o) then
				LG.saved[o] = o.BackgroundTransparency
				o.BackgroundTransparency = 0.6
			end
		end
	else
		GL.alpha, GL.blur = LG.prevAlpha, LG.prevBlur
		A.rowAlpha.idle, A.rowAlpha.hover = 0.35, 0.2
		glassApply()
		for o, t in pairs(LG.saved) do
			if o.Parent then o.BackgroundTransparency = t end
		end
		LG.saved = {}
	end
	LG.rim.Visible = v
	LG.top.Visible = v
	LG.glowHolder.Visible = v
end

-- re-applies the glass look to rows that were created or changed since it was switched on
function LG.reapply()
	if not LG.on then return end
	glassApply()
	for _, o in ipairs(window:GetDescendants()) do
		if isGlassRow(o) then
			if LG.saved[o] == nil then LG.saved[o] = o.BackgroundTransparency end
			o.BackgroundTransparency = 0.6
		end
	end
	LG.rim.Visible = true
	LG.top.Visible = true
	LG.glowHolder.Visible = true
end

local lgConn = RunService.Heartbeat:Connect(function()
	local shown = window.Visible and window.GroupTransparency < 0.5
	if shown and not LG.wasShown then
		LG.wasShown = true
		LG.snap = true
		LG.reapply()
	elseif not shown then
		LG.wasShown = false
	end
	if not LG.on or not shown then return end
	local m = UserInputService:GetMouseLocation()
	local ap, as = window.AbsolutePosition, window.AbsoluteSize
	local sc = math.max(uiScales[1].Scale, 0.01)
	local tx = math.clamp((m.X - ap.X) / sc, 0, as.X / sc)
	local ty = math.clamp((m.Y - (A.guiInset or 0) - ap.Y) / sc, 0, as.Y / sc)
	if LG.snap then
		LG.mx, LG.my = tx, ty
		LG.snap = false
	else
		LG.mx += (tx - LG.mx) * 0.18
		LG.my += (ty - LG.my) * 0.18
	end
	for _, g in ipairs(LG.glow) do g.Position = UDim2.fromOffset(LG.mx, LG.my) end
	LG.rimGrad.Rotation = 20 + (LG.mx / math.max(as.X / sc, 1)) * 80
end)
onCleanup(function() lgConn:Disconnect() end)

toggle(sUI4, "Liquid Glass (beta)", false, function(v) setLG(v) end)

