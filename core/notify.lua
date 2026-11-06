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

function A.notify(title, body, kind)
	local accent = kind == "bad" and T.bad or kind == "good" and T.good or T.accent

	-- A CanvasGroup, so GroupTransparency can fade the whole card on the way out.
	-- As a plain Frame only the background faded: the text stayed fully opaque
	-- until the toast was destroyed, which read as a hard cut.
	local card = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, 54), BackgroundColor3 = T.raised,
		BackgroundTransparency = 0.06, GroupTransparency = 0, ClipsDescendants = true, Parent = toastLayer,
	})
	corner(card, 8)
	stroke(card, T.stroke, 0.35)

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

	task.delay(3.6, function()
		if card and card.Parent then
			tween(pop, 0.3, { Scale = 0.6 })
			tween(card, 0.3, { GroupTransparency = 1 })
			task.wait(0.22)
			card:Destroy()
		end
	end)
end

A.stage("1 helpers + toasts done")

