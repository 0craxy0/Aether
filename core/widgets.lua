local A = ...
local new, tween, corner, label = A.new, A.tween, A.corner, A.label
local T, FONT, notify = A.T, A.FONT, A.notify
local UserInputService = A.UserInputService
local motion, sfx = A.motion, A.sfx

local registry = {}      -- search + config index
local accentLinks = {}   -- objects that repaint on accent change
local KB = {
	active = {}, index = {}, onToggle = function(_name, _v) end,
	listening = false, -- true while a keybind row is waiting for a key
	bindings = {},     -- bind name -> { clear }, so a key can only belong to one row
	binds = { ["Fly"] = "Toggle fly", ["Aimbot"] = "Toggle aimbot", ["Silent aim"] = "Toggle silent aim", ["Kill aura"] = "Toggle kill aura" },
}
for i, n in ipairs({ "Fly", "Aimbot", "Silent aim", "Kill aura", "Player ESP", "Noclip", "Infinite jump", "Fullbright", "Remove fog", "Disable particles", "Anti-AFK", "Auto-execute on teleport" }) do
	KB.index[n] = i
end
KB.opts = { sliderRelease = true }
A.registry, A.accentLinks, A.KB = registry, accentLinks, KB

local function register(row, name, load, save)
	registry[#registry + 1] = { row = row, name = name, load = load, save = save }
end
A.register = register

local function rowBaseRaw(parent, height)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, height or 34),
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.35,
		BorderSizePixel = 0, Parent = parent,
	})
	corner(r, 7)
	return r
end

-- hover targets for rows; Liquid Glass changes these so hovering can't turn rows solid again
A.rowAlpha = { idle = 0.35, hover = 0.2 }

local function rowBase(parent, height)
	local r = rowBaseRaw(parent, height)
	r.ClipsDescendants = true -- keeps a click ripple inside the row it belongs to
	r.MouseEnter:Connect(function()
		tween(r, 0.15, { BackgroundTransparency = A.rowAlpha.hover })
		sfx("hover")
	end)
	r.MouseLeave:Connect(function() tween(r, 0.15, { BackgroundTransparency = A.rowAlpha.idle }) end)
	return r
end

local function rowLabel(parent, text, name)
	return label({ Text = text, Font = FONT.med, TextSize = 12, Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -90, 1, 0), Name = name, Parent = parent })
end
A.rowBaseRaw, A.rowBase, A.rowLabel = rowBaseRaw, rowBase, rowLabel

-- toggle ------------------------------------------------------
function A.toggle(parent, name, default, onChanged)
	local r = rowBase(parent)
	rowLabel(r, name, name)

	local switch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(40, 24), BackgroundColor3 = T.stroke, BorderSizePixel = 0, Parent = r,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- registered on first hover: the field only ever holds controls near the cursor
	r.MouseEnter:Connect(function() motion.magnet(switch, 28, 3.5) end)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = switch,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = r })
	local state = false

	local function set(v, silent)
		state = v; KB.active[name] = v or nil; KB.onToggle(name, v)
		tween(knob, 0.5, { Position = UDim2.new(0, v and 18 or 2, 0.5, 0) }, Enum.EasingStyle.Elastic)
		tween(switch, 0.25, { BackgroundColor3 = v and T.good or T.stroke })
		if not silent then
			sfx(v and "on" or "off")
			switch.Size = UDim2.fromOffset(45, 27) -- a small give, like a real switch
			task.delay(0.01, function()
				if switch.Parent then
					tween(switch, 0.5, { Size = UDim2.fromOffset(40, 24) }, Enum.EasingStyle.Elastic)
				end
			end)
		end
		if not silent and onChanged then
			local ok, err = pcall(onChanged, v)
			if not ok then notify(name, tostring(err), "bad") end
		end
	end

	hit.MouseButton1Click:Connect(function()
		local m = UserInputService:GetMouseLocation()
		motion.ripple(r, m.X - r.AbsolutePosition.X, m.Y - r.AbsolutePosition.Y)
		set(not state)
		knob.Size = UDim2.fromOffset(30, 16)
		tween(knob, 0.6, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Elastic)
	end)
	register(r, name, function(v) set(v, true) end)
	registry[#registry].load = function(v) set(v and true or false) end
	registry[#registry].save = function() return state end
	if default then
		set(true, true)
		if onChanged then pcall(onChanged, true) end
	end
	return { set = set, get = function() return state end, row = r }
end

-- slider ------------------------------------------------------
function A.slider(parent, name, min, max, default, onChanged)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = parent })
	corner(r, 7)

	label({ Text = name, Font = FONT.med, TextSize = 12, Position = UDim2.fromOffset(11, 8), Size = UDim2.new(1, -112, 0, 14), Parent = r })
	local val = label({ Text = tostring(default), Font = FONT.bold, TextSize = 12, TextColor3 = T.accent, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -60, 0, 8), Size = UDim2.fromOffset(49, 14), Parent = r })
	accentLinks[#accentLinks + 1] = { obj = val, kind = "text" }
	val.Visible = false
	local valBox = new("TextBox", {
		Text = tostring(default), Font = FONT.bold, TextSize = 12, TextColor3 = T.accent,
		TextXAlignment = Enum.TextXAlignment.Right, BackgroundTransparency = 1, ClearTextOnFocus = false,
		Position = UDim2.new(1, -60, 0, 4), Size = UDim2.fromOffset(49, 22), Parent = r,
	})
	accentLinks[#accentLinks + 1] = { obj = valBox, kind = "text" }

	local track = new("Frame", { Position = UDim2.fromOffset(11, 31), Size = UDim2.new(1, -22, 0, 4), BackgroundColor3 = T.stroke, BorderSizePixel = 0, Parent = r }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = T.accent, BorderSizePixel = 0, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	accentLinks[#accentLinks + 1] = { obj = fill, kind = "fill" }
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 22), Parent = r })
	local value = default
	local dragging = false
	local acc = default
	local freeNext = false -- true only for typed or loaded values, which may exceed min/max
	local lastX = nil
	local fineOff = 0
	local commitToken = 0
	local function commitNow()
		commitToken += 1
		if onChanged then pcall(onChanged, value) end
	end
	local function queueCommit()
		if not onChanged then return end
		commitToken += 1
		local t = commitToken
		if dragging then
			if not KB.opts.sliderRelease then pcall(onChanged, value) end
			return
		end
		task.delay(0.2, function()
			if t == commitToken then pcall(onChanged, value) end
		end)
	end
	local endConn = UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if dragging then
				tween(knob, 0.6, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Elastic)
				dragging = false
				commitNow()
			end
		end
	end)

	local function set(v, silent)
		if freeNext then acc = v else acc = math.clamp(v, min, max) end
		value = math.floor(acc + 0.5)
		local a = math.clamp((value - min) / (max - min), 0, 1)
		tween(fill, 0.08, { Size = UDim2.fromScale(a, 1) })
		tween(knob, 0.08, { Position = UDim2.fromScale(a, 0.5) })
		val.Text = tostring(value)
		if not valBox:IsFocused() then valBox.Text = tostring(value) end
		if not silent then queueCommit() end
	end

	local function fromX(x)
		local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		local fine = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if lastX and fine then
			fineOff = fineOff - (x - lastX) / math.max(track.AbsoluteSize.X, 1) * (max - min) * 0.9
		end
		lastX = x
		set(min + rel * (max - min) + fineOff)
	end

	valBox.FocusLost:Connect(function()
		local n = tonumber((valBox.Text:gsub("[^%d%.%-]", "")))
		if n then
			freeNext = true
			set(n)
			freeNext = false
		end
		valBox.Text = tostring(value)
	end)

	local function stepper(txt, xOff, dir)
		local b = new("TextButton", {
			Text = txt, Font = FONT.bold, TextSize = 13, TextColor3 = T.text,
			BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 7),
			Size = UDim2.fromOffset(18, 18), Parent = r,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		local hold = 0
		b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.accent }) end)
		b.MouseLeave:Connect(function()
			hold += 1
			tween(b, 0.12, { BackgroundColor3 = T.stroke })
		end)
		b.MouseButton1Up:Connect(function() hold += 1 end)
		b.MouseButton1Down:Connect(function()
			hold += 1
			local id = hold
			local big = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 10 or 1
			set(value + dir * big)
			task.spawn(function()
				task.wait(0.4)
				while hold == id and b.Parent do
					set(value + dir * big)
					task.wait(0.05)
				end
			end)
		end)
	end
	stepper("−", -86, -1)
	stepper("+", -66, 1)

	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; lastX = nil; fineOff = 0
			tween(knob, 0.6, { Size = UDim2.fromOffset(24, 24) }, Enum.EasingStyle.Elastic)
			fromX(i.Position.X)
		end
	end)
	local moveConn = UserInputService.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) or i.UserInputType == Enum.UserInputType.Touch then
				fromX(i.Position.X)
			end
		end
	end)

	register(r, name, function(v) set(v, true) end)
	registry[#registry].load = function(v)
		freeNext = true
		set(v)
		freeNext = false
	end
	r.Destroying:Connect(function() moveConn:Disconnect(); endConn:Disconnect() end)
	registry[#registry].save = function() return value end
	set(default, true)
	return { set = set, get = function() return value end, row = r }
end

-- button ------------------------------------------------------
function A.button(parent, name, text, callback)
	text = text:sub(1, 1) .. text:sub(2):lower()
	local r = rowBase(parent)
	rowLabel(r, name, name)
	local b = new("TextButton", {
		Text = text, Font = FONT.bold, TextSize = 11, TextColor3 = T.text,
		BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(74, 22), Parent = r,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	b.MouseEnter:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.accent }) end)
	b.MouseLeave:Connect(function() tween(b, 0.12, { BackgroundColor3 = T.stroke }) end)
	r.MouseEnter:Connect(function() motion.magnet(b, 24, 2.5) end)
	b.MouseButton1Click:Connect(function()
		local m = UserInputService:GetMouseLocation()
		motion.ripple(r, m.X - r.AbsolutePosition.X, m.Y - r.AbsolutePosition.Y)
		sfx("tap")
		b.Size = UDim2.fromOffset(58, 16)
		tween(b, 0.6, { Size = UDim2.fromOffset(74, 22) }, Enum.EasingStyle.Elastic)
		local ok, err = pcall(callback)
		if not ok then notify(name, tostring(err), "bad") end
	end)
	register(r, name)
end

-- dropdown ----------------------------------------------------
function A.dropdown(parent, name, options, default, onChanged)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0, ClipsDescendants = true, Parent = parent })
	corner(r, 7)
	rowLabel(r, name, name)

	local sel = new("TextButton", {
		Text = default, Font = FONT.med, TextSize = 11, TextColor3 = T.text,
		BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 6),
		Size = UDim2.fromOffset(96, 22), Parent = r,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	r.MouseEnter:Connect(function() motion.magnet(sel, 24, 2) end)

	local list = new("Frame", { Position = UDim2.fromOffset(9, 34), Size = UDim2.new(1, -18, 0, 0), BackgroundTransparency = 1, Parent = r }, {
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local open = false
	for i, opt in ipairs(options) do
		local e = new("TextButton", {
			Text = opt, Font = FONT.reg, TextSize = 11, TextColor3 = T.muted,
			BackgroundColor3 = T.panel, AutoButtonColor = false, BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Parent = list,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		e.MouseButton1Click:Connect(function()
			sfx("tap", 0.8)
			sel.Text = opt
			open = false
			r.Size = UDim2.new(1, 0, 0, 34)
			list.Size = UDim2.new(1, -18, 0, 0)
			if onChanged then pcall(onChanged, opt) end
		end)
	end

	sel.MouseButton1Click:Connect(function()
		open = not open
		if open then
			r.Size = UDim2.new(1, 0, 0, 40 + #options * 25)
			list.Size = UDim2.new(1, -18, 0, #options * 25)
		else
			r.Size = UDim2.new(1, 0, 0, 34)
			list.Size = UDim2.new(1, -18, 0, 0)
		end
	end)

	register(r, name, function(v)
		sel.Text = v
		if onChanged then pcall(onChanged, v) end
	end, function() return sel.Text end)
	return { get = function() return sel.Text end, row = r }
end

-- colour picker ------------------------------------------------
-- Hue and saturation are picked by dragging over a 2D field; brightness is a
-- separate bar underneath. Collapsing value into the field is the common
-- shortcut and it is wrong: the bottom of a hue/sat square is black at every
-- hue, so once you drag down you can no longer see which colour you picked.

function A.colorPicker(parent, name, default, onChanged)
	local r = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.35,
		BorderSizePixel = 0, ClipsDescendants = true, Parent = parent,
	})
	corner(r, 7)
	local pad = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Position = UDim2.fromOffset(11, 0), Parent = r,
	}, {
		new("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 11) }),
		new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- header: name, hex readout, current swatch
	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = 1, Parent = pad })
	label({ Text = name, Font = FONT.med, TextSize = 12, Size = UDim2.new(1, -96, 1, 0), Parent = head })
	local hexLbl = label({
		Text = "#000000", RichText = false, Font = FONT.bold, TextSize = 10, TextColor3 = T.muted,
		TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, -46, 0, 24), Parent = head,
	})
	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(38, 22), BorderSizePixel = 0, Parent = head,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }), new("UIStroke", { Color = T.stroke, Transparency = 0.2, Thickness = 1 }) })

	-- field: horizontal white gradient over a vertical transparent one gives the
	-- classic saturation-left / hue-up square
	local field = new("Frame", { Size = UDim2.new(1, 0, 0, 96), BorderSizePixel = 0, LayoutOrder = 2, Parent = pad }, {
		new("UICorner", { CornerRadius = UDim.new(0, 6) }),
	})
	local hueOverlay = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = field,
	})
	local hueGrad = new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0) }),
		Parent = hueOverlay,
	})
	-- static: white at the left edge fading to clear, so the field reads as
	-- saturation 0 -> 1 across its width
	local satOverlay = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = field,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 6) }),
		new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1),
		}) }),
	})
	local marker = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(14, 14),
		BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = field,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.1 }) })

	-- brightness bar
	local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 14), BorderSizePixel = 0, LayoutOrder = 3, Parent = pad }, {
		new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		new("UIGradient", { Rotation = 0, Color = NumberSequence.new({
			NumberSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
			NumberSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
		}) }),
	})
	local barKnob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 3, Parent = bar,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }), new("UIStroke", { Color = T.stroke, Thickness = 1 }) })

	local hue, sat, val = 0.58, 1, 1
	local color = default

	local function parse(c)
		if typeof(c) ~= "Color3" then return end
		color = c
		-- toHSV returns hue in 0..1, not degrees
		local h, s, v = Color3.toHSV(c)
		hue, sat, val = h, s, v
	end

	local function paint()
		-- the field is the pure hue, dimmed uniformly as value drops
		field.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		local dark = 1 - val
		if hueGrad then
			hueGrad.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, dark),
				NumberSequenceKeypoint.new(1, dark),
			})
		end
		marker.Position = UDim2.fromScale(math.clamp(sat, 0, 1), math.clamp(1 - val, 0, 1))
		barKnob.Position = UDim2.fromScale(math.clamp(val, 0, 1), 0.5)
		color = Color3.fromHSV(hue, sat, val)
		swatch.BackgroundColor3 = color
		hexLbl.Text = string.format("#%02X%02X%02X",
			math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	end

	local function emit()
		if onChanged then pcall(onChanged, color) end
	end

	local dragField, dragBar = false, false
	local function applyField(x, y)
		local ap, as = field.AbsolutePosition, field.AbsoluteSize
		hue = math.clamp((y - ap.Y) / math.max(as.Y, 1), 0, 1)
		sat = math.clamp((x - ap.X) / math.max(as.X, 1), 0, 1)
		paint()
		emit()
	end
	local function applyBar(x)
		local ap, as = bar.AbsolutePosition, bar.AbsoluteSize
		val = math.clamp((x - ap.X) / math.max(as.X, 1), 0, 1)
		paint()
		emit()
	end

	local fieldHit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = field })
	local barHit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 16, 1, 16), Position = UDim2.fromOffset(-8, -8), ZIndex = 4, Parent = bar })

	fieldHit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragField = true
			tween(marker, 0.4, { Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Elastic)
			applyField(i.Position.X, i.Position.Y)
		end
	end)
	barHit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragBar = true
			applyBar(i.Position.X)
		end
	end)

	local moveConn = UserInputService.InputChanged:Connect(function(i)
		if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
		if dragField then applyField(i.Position.X, i.Position.Y)
		elseif dragBar then applyBar(i.Position.X) end
	end)
	local endConn = UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			if dragField then tween(marker, 0.4, { Size = UDim2.fromOffset(14, 14) }, Enum.EasingStyle.Elastic) end
			dragField, dragBar = false, false
		end
	end)
	A.onCleanup(function() moveConn:Disconnect(); endConn:Disconnect() end)

	parse(default)
	paint()
	register(r, name, function(v) parse(v); paint(); emit() end, function() return color end)
	return { get = function() return color end, row = r, set = function(c) parse(c); paint(); emit() end }
end

-- keybind -----------------------------------------------------
A.keybinds = {}

function A.keybind(parent, name, default)
	local keybinds = A.keybinds
	local r = rowBase(parent)
	rowLabel(r, name, name)
	local b = new("TextButton", {
		Text = default or "—", Font = FONT.bold, TextSize = 11, TextColor3 = T.text,
		BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(56, 22), Parent = r,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })

	r.MouseEnter:Connect(function() motion.magnet(b, 22, 2.5) end)

	local listening = false
	local key = nil

	-- the only writer of the keybinds map, so a key can never point at two rows
	local function apply(newKey)
		local other = newKey and keybinds[newKey]
		if other and other ~= name then
			local o = KB.bindings[other]
			if o then o.clear() else keybinds[newKey] = nil end
		end
		if key and keybinds[key] == name then keybinds[key] = nil end
		key = newKey
		b.Text = newKey or "—"
		if newKey then keybinds[newKey] = name end
	end

	KB.bindings[name] = {
		clear = function()
			if key and keybinds[key] == name then keybinds[key] = nil end
			key = nil
			b.Text = "—"
		end,
	}

	b.MouseButton1Click:Connect(function()
		listening = true
		KB.listening = true -- tail/keybinds.lua must not also fire the key being replaced
		tween(b, 0.12, { BackgroundColor3 = T.accent })
		b.Text = "…"
	end)

	local conn = UserInputService.InputBegan:Connect(function(i, gp)
		if listening and not gp then
			listening = false
			KB.listening = false
			tween(b, 0.15, { BackgroundColor3 = T.stroke })
			apply(i.KeyCode.Name)
		end
	end)
	A.onCleanup(function() conn:Disconnect() end)

	apply(default)
	register(r, name, function(v) apply(v) end, function() return key end)
	return { get = function() return key end, row = r, conn = conn }
end
