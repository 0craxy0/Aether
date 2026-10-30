local A = ...
local new, tween, corner, label = A.new, A.tween, A.corner, A.label
local T, FONT, notify = A.T, A.FONT, A.notify
local UserInputService = A.UserInputService

local registry = {}      -- search + config index
local accentLinks = {}   -- objects that repaint on accent change
local KB = {
	active = {}, index = {}, onToggle = function(_name, _v) end,
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
	r.MouseEnter:Connect(function() tween(r, 0.15, { BackgroundTransparency = A.rowAlpha.hover }) end)
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
		if not silent and onChanged then
			local ok, err = pcall(onChanged, v)
			if not ok then notify(name, tostring(err), "bad") end
		end
	end

	hit.MouseButton1Click:Connect(function()
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
	b.MouseButton1Click:Connect(function()
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

	local listening = false
	local key = default

	b.MouseButton1Click:Connect(function()
		listening = true
		tween(b, 0.12, { BackgroundColor3 = T.accent })
		b.Text = "…"
	end)

	local conn = UserInputService.InputBegan:Connect(function(i, gp)
		if listening and not gp then
			listening = false
			tween(b, 0.15, { BackgroundColor3 = T.stroke })
			if key then keybinds[key] = nil end
			key = i.KeyCode.Name
			b.Text = key
			keybinds[key] = name
		end
	end)
	if key then keybinds[key] = name end

	register(r, name, function(v)
		if key then keybinds[key] = nil end
		key = v; b.Text = v; keybinds[v] = name
	end, function() return key end)
	return { get = function() return key end, row = r, conn = conn }
end

