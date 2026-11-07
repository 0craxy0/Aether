local A = ...
local new, tween, corner, stroke, pad, drawX, label = A.new, A.tween, A.corner, A.stroke, A.pad, A.drawX, A.label
local T, FONT, LP, screen, EL = A.T, A.FONT, A.LP, A.screen, A.EL
local UserInputService = A.UserInputService

local W, H = 580, 430
A.W, A.H = W, H

-- how far the shadow extends past the window on every side
local PAD = 22

-- One image stretched across the whole shadow, then shaped by a single UICorner.
-- It was 9-sliced before, which kept the sprite's corners at native size (~20px)
-- while the corner below cuts a much larger arc - the clip sliced through the
-- sprite's solid core and left a hard edge. Stretched, the alpha ramps across the
-- whole face, so the clip can only ever remove pixels that are already near clear.
local shadow = new("ImageLabel", {
	Image = "rbxassetid://1316045217", ScaleType = Enum.ScaleType.Stretch,
	ImageColor3 = Color3.new(0, 0, 0),
	ImageTransparency = 0.4, BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W + PAD * 2, H + PAD * 2), Parent = screen,
})

local window = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H), BackgroundColor3 = T.bg,
	BackgroundTransparency = 0.06, BorderSizePixel = 0, Parent = screen,
})
corner(window, 11)
stroke(window, Color3.new(1, 1, 1), 0.86)

-- The shadow sits PAD outside the window, so its curve is the window's radius plus
-- that inset, which keeps the two arcs concentric. Recomputed on rescale in
-- pages/ui.lua. The window's own corner is untouched.
local wCorner = window:FindFirstChildOfClass("UICorner")
A.windowCorner = wCorner and wCorner.CornerRadius.Offset or 19
A.shadowPad = PAD
new("UICorner", { CornerRadius = UDim.new(0, A.windowCorner + PAD), Parent = shadow })
-- The sheen is a square frame laid over a rounded shell. CanvasGroup does not
-- clip its children, so its corners used to stick out past the window's arc;
-- the same radius keeps it inside, and the gradient is already clear at the
-- bottom, so the corners it rounds there are invisible anyway.
new("Frame", { Name = "sheen", Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Active = false, Parent = window }, {
	new("UICorner", { CornerRadius = UDim.new(0, A.windowCorner) }),
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1) }) }),
})

local header = new("Frame", {
	Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Parent = window,
})

label({ Text = "Aether", Font = FONT.bold, TextSize = 18, Position = UDim2.fromOffset(18, 11), Size = UDim2.fromOffset(140, 22), Parent = header })
label({
	Text = string.format("<font color=\"#79818C\">%s</font>  ·  <font color=\"#79818C\">%s</font>  ·  <font color=\"#79818C\">%s</font>", A.executorName, LP.Name, tostring(A.build or "?")),
	TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(18, 31), Size = UDim2.fromOffset(430, 14), Parent = header,
})

local closeBtn = new("TextButton", {
	Text = "", Font = FONT.med, TextSize = 14, TextColor3 = T.muted,
	BackgroundColor3 = T.raised, AutoButtonColor = false, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
	Size = UDim2.fromOffset(26, 26), Parent = header,
}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }) })

drawX(closeBtn, 11, T.muted)
closeBtn.MouseEnter:Connect(function() for _, a in ipairs(closeBtn:GetChildren()) do if a.Name == "xarm" then tween(a, 0.12, { BackgroundColor3 = T.text }) end end end)
closeBtn.MouseLeave:Connect(function() for _, a in ipairs(closeBtn:GetChildren()) do if a.Name == "xarm" then tween(a, 0.12, { BackgroundColor3 = T.muted }) end end end)

local search = new("Frame", {
	Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -28, 0, 30),
	BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = window,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 7) }),
	new("UIStroke", { Color = T.stroke, Transparency = 0.4, Thickness = 1 }),
})

local searchBox = new("TextBox", {
	Text = "", PlaceholderText = "Search", PlaceholderColor3 = T.muted,
	BackgroundTransparency = 1, Font = FONT.reg, TextSize = 12, TextColor3 = T.text,
	TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
	-- right side is left clear for the match counter tail/startup.lua adds
	Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -84, 1, 0), Parent = search,
})

local body = new("Frame", {
	Position = UDim2.fromOffset(14, 100), Size = UDim2.new(1, -28, 1, -114),
	BackgroundTransparency = 1, Parent = window,
})

local sidebar = new("Frame", {
	Size = UDim2.new(0, 140, 1, 0),
	BackgroundColor3 = T.panel, BorderSizePixel = 0, Parent = body,
})
corner(sidebar, 9)
pad(sidebar, 7)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = sidebar })

local content = new("Frame", {
	Position = UDim2.fromOffset(150, 0), Size = UDim2.new(1, -150, 1, 0),
	BackgroundTransparency = 1, Parent = body,
})

-- ── drag ──────────────────────────────────────────────────────
do
	local dragging, startPos, origin
	header.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, origin = true, i.Position, window.Position; EL.grab(window.Position, window.AbsoluteSize)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - startPos
			window.Position = EL.pos(UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y), window.AbsoluteSize)
			shadow.Position = window.Position
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

A.shadow, A.window, A.header, A.closeBtn = shadow, window, header, closeBtn
A.search, A.searchBox, A.body, A.sidebar, A.content = search, searchBox, body, sidebar, content

-- mask list (Drawing visuals avoid these) and per-frame UIScales; makeConfig extends both
A.maskGuis = { window }
A.uiScales = { new("UIScale", { Parent = window }) }

A.stage("2 window built")

