local A = ...
local new, tween, onCleanup = A.new, A.tween, A.onCleanup
local T, TweenService = A.T, A.TweenService
local RunService, UserInputService = A.RunService, A.UserInputService
local window = A.window

-- Motion: things arrive instead of appearing, controls lean toward the cursor,
-- and a press leaves a ripple in the material. Every part is switchable.
local M = { enabled = true, magnetOn = true, items = {}, seen = setmetatable({}, { __mode = "k" }) }
A.motion = M

-- A.tween has no delay, and the whole language here is timing
local function tw(o, dur, props, style, delay)
	local info = TweenInfo.new(dur, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay or 0)
	local t = TweenService:Create(o, info, props)
	t:Play()
	return t
end

local function ordered(parent)
	-- GetChildren also returns the layout, padding and scale objects a container
	-- carries; only GuiObjects can be ordered, animated or measured
	local kids = {}
	for _, c in ipairs(parent:GetChildren()) do
		if c:IsA("GuiObject") then kids[#kids + 1] = c end
	end
	table.sort(kids, function(a, b)
		if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
		return a.Name < b.Name
	end)
	return kids
end

local function scaleOf(o)
	local s = o:FindFirstChildOfClass("UIScale")
	if not s then s = new("UIScale", { Parent = o }) end
	return s
end

-- Staggered entrance: headers then rows, each one settling from 96.5% while its
-- text and background fade up. Budgeted so a long page still lands in <0.7s.
function M.reveal(root, opts)
	if not M.enabled or not root then return end
	opts = opts or {}
	local stagger = opts.stagger or 0.013
	local dur = opts.duration or 0.3
	local budget = opts.max or 26
	local n = 0

	local function anim(o)
		if n >= budget or not o.Parent or not o:IsA("GuiObject") then return end
		n += 1
		local delay = (n - 1) * stagger
		local sc = scaleOf(o)
		sc.Scale = 0.965
		tw(sc, dur, { Scale = 1 }, Enum.EasingStyle.Back, delay)
		if o.BackgroundTransparency < 1 then
			local base = o.BackgroundTransparency
			o.BackgroundTransparency = 1
			tw(o, dur, { BackgroundTransparency = base }, Enum.EasingStyle.Quad, delay)
		end
		for _, d in ipairs(o:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox")) and d.TextTransparency < 1 then
				local base = d.TextTransparency
				d.TextTransparency = 1
				tw(d, dur, { TextTransparency = base }, Enum.EasingStyle.Quad, delay)
			end
		end
	end

	for _, child in ipairs(ordered(root)) do
		if child:FindFirstChildOfClass("UIListLayout") then
			for _, row in ipairs(ordered(child)) do anim(row) end
		else
			anim(child)
		end
	end
end

-- Magnetism: a control leans a few pixels toward the cursor while it is near
function M.magnet(obj, radius, strength)
	if not obj or M.seen[obj] then return end -- once per control, on first hover
	M.seen[obj] = true
	M.items[#M.items + 1] = {
		obj = obj, base = obj.Position,
		radius = radius or 24, strength = strength or 3, ox = 0, oy = 0,
	}
end

function M.ripple(o, x, y)
	if not M.enabled or not o then return end
	local w, h = o.AbsoluteSize.X, o.AbsoluteSize.Y
	local size = math.max(w, h) * 0.95
	local dot = new("Frame", {
		Name = "ripple", AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x or w / 2, y or h / 2), Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = T.text, BackgroundTransparency = 0.78,
		BorderSizePixel = 0, ZIndex = 2, Parent = o,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	tween(dot, 0.42, { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
	task.delay(0.45, function() if dot.Parent then dot:Destroy() end end)
end

local function magnetStep(dt)
	local wp, ws = window.AbsolutePosition, window.AbsoluteSize
	local m = UserInputService:GetMouseLocation()
	-- pointer is in window space, the control in AbsolutePosition space
	m = Vector2.new(m.X, m.Y - (A.guiInset or 0))
	if m.X < wp.X - 48 or m.X > wp.X + ws.X + 48 or m.Y < wp.Y - 48 or m.Y > wp.Y + ws.Y + 48 then return end
	local k = 1 - math.exp(-dt * 14)
	for _, it in ipairs(M.items) do
		local o = it.obj
		if o.Parent then
			local p, s = o.AbsolutePosition, o.AbsoluteSize
			local dx, dy = m.X - (p.X + s.X / 2), m.Y - (p.Y + s.Y / 2)
			local dist = math.sqrt(dx * dx + dy * dy)
			local tx, ty = 0, 0
			if dist < it.radius and dist > 0.01 then
				local pull = (1 - dist / it.radius) * it.strength
				tx, ty = dx / dist * pull, dy / dist * pull
			end
			it.ox += (tx - it.ox) * k
			it.oy += (ty - it.oy) * k
			local b = it.base
			o.Position = UDim2.new(b.X.Scale, b.X.Offset + it.ox, b.Y.Scale, b.Y.Offset + it.oy)
		end
	end
end

-- Magnetism can be switched off while a control is leaning (the UI page's
-- "Cursor magnetism" row, or "Entrance motion" above it). The heartbeat used to
-- return early in that state, which froze the lean where it was: a control left
-- a few pixels off its row until it was hovered again. Put it back instead.
local function settle()
	for _, it in ipairs(M.items) do
		if it.ox ~= 0 or it.oy ~= 0 then
			it.ox, it.oy = 0, 0
			if it.obj.Parent then it.obj.Position = it.base end
		end
	end
end

local conn = RunService.Heartbeat:Connect(function(dt)
	if not (M.enabled and M.magnetOn) then settle(); return end
	if #M.items == 0 then return end
	if not (window.Visible and window.GroupTransparency < 0.98) then return end
	magnetStep(math.min(dt, 1 / 30))
end)
onCleanup(function() conn:Disconnect() end)
