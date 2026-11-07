local A = ...
local new, tween, corner, stroke, label = A.new, A.tween, A.corner, A.stroke, A.label
local T, FONT, LP = A.T, A.FONT, A.LP

local gui
pcall(function()
	gui = A.has.gethui and gethui() or game:GetService("CoreGui")
end)
if not gui then gui = LP:WaitForChild("PlayerGui") end

local screen = new("ScreenGui", {
	Name = "\0Aether", ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true, Parent = gui,
})
A.screen = screen

local toastLayer = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.fromOffset(268, 400), BackgroundTransparency = 1, ZIndex = 50, Parent = screen,
}, {
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 8) }),
})
A.toastLayer = toastLayer

-- Live toasts, oldest first. Without a ceiling, one module erroring on every
-- frame stacks cards faster than they expire: the layer grows without bound and
-- the whole ScreenGui starts costing frame time.
local MAX_TOASTS = 4
local live = {}

local function retire(card)
	for i = #live, 1, -1 do
		if live[i] == card then table.remove(live, i) end
	end
	card:Destroy()
end

function A.notify(title, body, kind)
	local accent = kind == "bad" and T.bad or kind == "good" and T.good or T.accent

	-- make room before building the new card, so the ceiling is never exceeded
	while #live >= MAX_TOASTS do
		local oldest = table.remove(live, 1)
		if oldest and oldest.Parent then oldest:Destroy() end
	end

	-- A CanvasGroup, so GroupTransparency can fade the whole card on the way out.
	-- As a plain Frame only the background faded: the text stayed fully opaque
	-- until the toast was destroyed, which read as a hard cut.
	local card = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = T.raised,
		BackgroundTransparency = 0.06, GroupTransparency = 0, ClipsDescendants = true, Parent = toastLayer,
	})
	corner(card, 8)
	stroke(card, T.stroke, 0.35)
	live[#live + 1] = card

	-- the intent bar: created clear and brought in, it never appeared at all
	local bar = new("Frame", { Size = UDim2.fromOffset(3, 34), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = card }, {
		new("UICorner", { CornerRadius = UDim.new(0, 3) }),
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.35),
		}) }),
	})
	tween(bar, 0.35, { BackgroundTransparency = 0 })

	label({ Text = title, Font = FONT.bold, TextSize = 12, Position = UDim2.fromOffset(13, 9), Size = UDim2.new(1, -24, 0, 14), Parent = card })
	label({ Text = body or "", TextColor3 = T.muted, TextSize = 11, Position = UDim2.fromOffset(13, 26), Size = UDim2.new(1, -24, 0, 26), TextWrapped = true, Parent = card })

	local pop = new("UIScale", { Scale = 0.3, Parent = card })
	tween(pop, 0.8, { Scale = 1 }, Enum.EasingStyle.Elastic)

	-- A toast that vanishes while it is being read is the most annoying thing a
	-- notification can do, so hovering holds it and moving off releases it. A
	-- click dismisses immediately - the card already looks like a button.
	local held, waiting, closing = false, false, false
	local function dismiss()
		if closing or not card.Parent then return end
		closing = true
		tween(pop, 0.3, { Scale = 0.6 })
		tween(card, 0.3, { GroupTransparency = 1 })
		task.delay(0.22, function() retire(card) end)
	end
	local function arm(after)
		task.delay(after, function()
			if closing or not card.Parent then return end
			if held then waiting = true; return end -- released by MouseLeave
			dismiss()
		end)
	end
	card.MouseEnter:Connect(function() held = true end)
	card.MouseLeave:Connect(function()
		held = false
		if waiting then waiting = false; dismiss() end
	end)
	-- CanvasGroup is a GuiObject, not a GuiButton - there is no MouseButton1Click
	-- on it, so the click has to come through InputBegan.
	card.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dismiss()
		end
	end)
	arm(3.6)
end

A.stage("1 helpers + toasts done")

