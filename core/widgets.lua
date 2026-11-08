local A = ...
local new, tween, corner, label = A.new, A.tween, A.corner, A.label
local T, FONT, notify = A.T, A.FONT, A.notify
local UserInputService = A.UserInputService
local motion, sfx = A.motion, A.sfx
local INSET = A.guiInset or 0

-- pointer in a row's own coordinates: the mouse is in window space, the row is
-- in AbsolutePosition space, and the two differ by the topbar inset
local function localPointer(obj)
	local m = UserInputService:GetMouseLocation()
	return m.X - obj.AbsolutePosition.X, m.Y - INSET - obj.AbsolutePosition.Y
end

local registry = {}      -- search + config index
local accentLinks = {}   -- objects that repaint on accent change
local setters = {}       -- toggle name -> its set(), for A.setToggle
local flips, flipAt = {}, {} -- rapid-flip counter, see set() below
local KB = {
	active = {}, index = {}, onToggle = function(_name, _v) end,
	listening = false, -- true while a keybind row is waiting for a key
	captureAt = nil,   -- os.clock() when that started, so a stale capture expires
	bindings = {},     -- bind name -> { clear }, so a key can only belong to one row
	binds = { ["Fly"] = "Toggle fly", ["Aimbot"] = "Toggle aimbot", ["Silent aim"] = "Toggle silent aim", ["Kill aura"] = "Toggle kill aura" },
}
for i, n in ipairs({ "Fly", "Aimbot", "Silent aim", "Kill aura", "Player ESP", "Noclip", "Infinite jump", "Fullbright", "Remove fog", "Disable particles", "Anti-AFK", "Auto-execute on teleport", "Infinite cold gas" }) do
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
	-- a 2px intent bar that lights up under the cursor: the row already changed
	-- brightness, but at 0.35 alpha on a dark panel that read as almost nothing
	local bar = new("Frame", {
		Name = "rowAccent", Size = UDim2.fromOffset(2, 14), AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = T.accent,
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = r,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	accentLinks[#accentLinks + 1] = { obj = bar, kind = "fill" }
	r.MouseEnter:Connect(function()
		tween(r, 0.15, { BackgroundTransparency = A.rowAlpha.hover })
		tween(bar, 0.15, { BackgroundTransparency = 0 })
		sfx("hover")
	end)
	r.MouseLeave:Connect(function()
		tween(r, 0.15, { BackgroundTransparency = A.rowAlpha.idle })
		tween(bar, 0.15, { BackgroundTransparency = 1 })
	end)
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
		if not silent then
			-- nine rapid flips of the same switch is not indecision, it is someone
			-- trying to break it; the panel is allowed to have an opinion
			local now = os.clock()
			if now - (flipAt[name] or 0) < 0.4 then
				flips[name] = (flips[name] or 0) + 1
			else
				flips[name] = 1
			end
			flipAt[name] = now
			if flips[name] == 9 and A.onFlipAbuse then
				local ok, err = pcall(A.onFlipAbuse, name, v)
				if not ok then warn("[Aether] flip hook: " .. tostring(err)) end
			end
		end
		if not silent and onChanged then
			local ok, err = pcall(onChanged, v)
			if not ok then notify(name, tostring(err), "bad") end
		end
		-- a committed change from the user marks the config dirty; the debounce
		-- and the "is a config being replayed right now" test live in settings
		if not silent and A.touch then A.touch() end
	end

	hit.MouseButton1Click:Connect(function()
		local mx, my = localPointer(r)
		motion.ripple(r, mx, my)
		set(not state)
		knob.Size = UDim2.fromOffset(30, 16)
		tween(knob, 0.6, { Size = UDim2.fromOffset(20, 20) }, Enum.EasingStyle.Elastic)
	end)
	register(r, name, function(v) set(v, true) end)
	registry[#registry].load = function(v) set(v and true or false) end
	registry[#registry].save = function() return state end
	registry[#registry].reset = function() set(default and true or false) end
	if default then
		set(true, true)
		if onChanged then pcall(onChanged, true) end
	end
	-- Flips a toggle the way a click would: through set() with onChanged firing,
	-- which is what a config replay deliberately does not do. tail/commands.lua
	-- needs that, because ";fly" has to actually start flying.
	setters[name] = set
	return { set = set, get = function() return state end, row = r }
end

function A.setToggle(name, v)
	local set = setters[name]
	if not set then return false, "no toggle named " .. tostring(name) end
	set(v and true or false)
	return true
end

-- slider ------------------------------------------------------
function A.slider(parent, name, min, max, default, onChanged)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = parent })
	corner(r, 7)

	label({ Text = name, Font = FONT.med, TextSize = 12, Position = UDim2.fromOffset(11, 8), Size = UDim2.new(1, -112, 0, 14), Parent = r })
	-- One value display, not two: the old pair left an invisible label sitting
	-- behind the editable box and registered it as an accent link, so every
	-- accent change repainted a label nobody could see.
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
	-- a malformed config could hand us min == max; dividing by that span would
	-- produce inf / nan and freeze the fill bar at an unreadable position
	local span = math.max(max - min, 1e-6)
	local function commitNow()
		commitToken += 1
		if onChanged then pcall(onChanged, value) end
		if A.touch then A.touch() end
	end
	local function queueCommit()
		if not onChanged then return end
		commitToken += 1
		local t = commitToken
		if dragging then
			if not KB.opts.sliderRelease then
				pcall(onChanged, value)
				if A.touch then A.touch() end
			end
			return
		end
		task.delay(0.2, function()
			if t == commitToken then
				pcall(onChanged, value)
				if A.touch then A.touch() end
			end
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
		v = tonumber(v) or default
		if freeNext then acc = v else acc = math.clamp(v, min, max) end
		value = math.floor(acc + 0.5)
		local a = math.clamp((value - min) / span, 0, 1)
		tween(fill, 0.08, { Size = UDim2.fromScale(a, 1) })
		tween(knob, 0.08, { Position = UDim2.fromScale(a, 0.5) })
		if not valBox:IsFocused() then valBox.Text = tostring(value) end
		if not silent then queueCommit() end
	end

	local function fromX(x)
		local rel = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		local fine = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		if lastX and fine then
			fineOff = fineOff - (x - lastX) / math.max(track.AbsoluteSize.X, 1) * span * 0.9
		end
		lastX = x
		set(min + rel * span + fineOff)
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
	-- Reset all settings replays this: snap back, then commit once, so the module
	-- sees the default immediately instead of 0.2s later through the debounce.
	registry[#registry].reset = function() freeNext = false; set(default, true); commitNow() end
	set(default, true)
	return { set = set, get = function() return value end, row = r }
end

-- input -------------------------------------------------------
-- A row with one text field. Commit on Enter or on losing focus, never per
-- keystroke: every caller here does something with the string (a search over
-- Workspace, a file on disk) and a per-key callback would run both sixty times.
function A.input(parent, name, placeholder, onCommit, defaultText)
	local r = rowBase(parent, 52)
	-- Two lines, not one: rowLabel stretches to the full row height and centres
	-- itself, which is right for a toggle but drew the label straight through the
	-- middle of the field and on top of its placeholder.
	label({
		Text = name, Font = FONT.med, TextSize = 12, TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(11, 8), Size = UDim2.new(1, -22, 0, 14), Parent = r,
	})
	local box = new("TextBox", {
		Text = tostring(defaultText or ""), PlaceholderText = placeholder or "",
		PlaceholderColor3 = T.muted, Font = FONT.reg, TextSize = 11, TextColor3 = T.text,
		BackgroundColor3 = T.panel, BackgroundTransparency = 0.25, BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		ClearTextOnFocus = false,
		Position = UDim2.fromOffset(11, 25), Size = UDim2.new(1, -22, 0, 21), Parent = r,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 5) }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
	})
	-- the field is the only part of the row that takes a click, so it is the one
	-- that has to say "you are typing here" - a focused box is otherwise identical
	-- parent goes in the props table: the third argument of new() is a list of
	-- children, so passing the box there hands ipairs an Instance
	local stroke = new("UIStroke", {
		Color = T.stroke, Thickness = 1, Transparency = 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = box,
	})
	accentLinks[#accentLinks + 1] = { obj = stroke, kind = "stroke" }

	local function commit()
		if onCommit then
			local ok, err = pcall(onCommit, box.Text)
			if not ok then notify(name, tostring(err), "bad") end
		end
	end
	box.FocusLost:Connect(commit)
	-- TextBox fires Focused / FocusLost. There is no FocusGained: the pair is not
	-- symmetric, which is how this got past a read-through.
	box.Focused:Connect(function()
		tween(box, 0.12, { BackgroundTransparency = 0 })
		stroke.Color = T.accent
		stroke.Transparency = 0
	end)
	box.FocusLost:Connect(function()
		tween(box, 0.15, { BackgroundTransparency = 0.25 })
		stroke.Color = T.stroke
		stroke.Transparency = 0.55
	end)
	box.MouseEnter:Connect(function() tween(box, 0.12, { BackgroundTransparency = 0 }) end)
	box.MouseLeave:Connect(function()
		if not box:IsFocused() then tween(box, 0.15, { BackgroundTransparency = 0.25 }) end
	end)

	register(r, name)
	return {
		row = r,
		box = box,
		get = function() return box.Text end,
		set = function(v) box.Text = tostring(v or "") end,
		focus = function() pcall(function() box:CaptureFocus() end) end,
	}
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
		local mx, my = localPointer(r)
		motion.ripple(r, mx, my)
		sfx("tap")
		b.Size = UDim2.fromOffset(58, 16)
		tween(b, 0.6, { Size = UDim2.fromOffset(74, 22) }, Enum.EasingStyle.Elastic)
		local ok, err = pcall(callback)
		if not ok then notify(name, tostring(err), "bad") end
	end)
	register(r, name)
end

-- dropdown ----------------------------------------------------
-- One list is open at a time. A click anywhere outside the row closes it, and so
-- does a page switch (core/pagekit.lua calls A.closeDropdowns) - an expanded row
-- left behind on a page nobody is looking at is otherwise invisible until the
-- page comes back with a dropdown the user never opened.
local openDropdowns = {}

local function closeDropdowns()
	for d in pairs(openDropdowns) do d.close() end
end
A.closeDropdowns = closeDropdowns

UserInputService.InputBegan:Connect(function(i)
	if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
	for d in pairs(openDropdowns) do
		if d.isOpen() then
			local p, s = d.row.AbsolutePosition, d.row.AbsoluteSize
			-- the input is in window space, the row in AbsolutePosition space
			local m = Vector2.new(i.Position.X, i.Position.Y - INSET)
			local inside = m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
			if not inside then d.close() end
		end
	end
end)

function A.dropdown(parent, name, options, default, onChanged)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0, ClipsDescendants = true, Parent = parent })
	corner(r, 7)
	rowLabel(r, name, name)

	local sel = new("TextButton", {
		Text = default, Font = FONT.med, TextSize = 11, TextColor3 = T.text,
		BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -9, 0, 6),
		Size = UDim2.fromOffset(96, 22), Parent = r,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 5) }),
		-- room for the caret, so a long option never runs underneath it
		new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 20) }),
	})

	-- caret: two arms of a "v", held in a frame so opening rotates both at once
	local caret = new("Frame", {
		Name = "caret", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, Parent = sel,
	})
	for i = 1, 2 do
		new("Frame", {
			Name = "arm", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(i == 1 and 3 or 7, 5),
			Size = UDim2.fromOffset(5, 1.5), Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = T.muted, BorderSizePixel = 0, Parent = caret,
		})
	end

	r.MouseEnter:Connect(function() motion.magnet(sel, 24, 2) end)

	local list = new("Frame", { Position = UDim2.fromOffset(9, 34), Size = UDim2.new(1, -18, 0, 0), BackgroundTransparency = 1, Parent = r }, {
		new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	local open = false
	local function setOpen(v)
		open = v
		r.Size = UDim2.new(1, 0, 0, v and (40 + #options * 25) or 34)
		list.Size = UDim2.new(1, -18, 0, v and (#options * 25) or 0)
		tween(caret, 0.18, { Rotation = v and 180 or 0 }, Enum.EasingStyle.Quint)
	end

	local function choose(opt, silent)
		sel.Text = opt
		if open then setOpen(false) end
		if onChanged then pcall(onChanged, opt) end
		if not silent and A.touch then A.touch() end
	end

	for i, opt in ipairs(options) do
		local e = new("TextButton", {
			Text = opt, Font = FONT.reg, TextSize = 11, TextColor3 = T.muted,
			BackgroundColor3 = T.panel, AutoButtonColor = false, BorderSizePixel = 0,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, Parent = list,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 4) }) })
		e.MouseEnter:Connect(function() tween(e, 0.1, { TextColor3 = T.text, BackgroundColor3 = T.raised }) end)
		e.MouseLeave:Connect(function() tween(e, 0.1, { TextColor3 = T.muted, BackgroundColor3 = T.panel }) end)
		e.MouseButton1Click:Connect(function()
			sfx("tap", 0.8)
			choose(opt)
		end)
	end

	sel.MouseButton1Click:Connect(function()
		local want = not open
		if want then closeDropdowns() end
		setOpen(want)
		if want then sfx("tap", 0.6) end
	end)

	local state = {
		row = r,
		close = function() if open then setOpen(false) end end,
		isOpen = function() return open end,
	}
	openDropdowns[state] = true
	r.Destroying:Connect(function() openDropdowns[state] = nil end)

	register(r, name, function(v) choose(v, true) end, function() return sel.Text end)
	registry[#registry].reset = function() choose(default) end
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

	r.MouseEnter:Connect(function() motion.magnet(b, 22, 2.5) end)

	local listening = false
	local key = nil

	-- the only writer of the keybinds map, so a key can never point at two rows
	local function apply(newKey)
		-- A blank or placeholder value must never become a bind: keybinds[""] would
		-- sit in the map looking bound, show nothing in the row, and swallow the key.
		if newKey ~= nil and (type(newKey) ~= "string" or newKey == "" or newKey == "—") then
			newKey = nil
		end
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
		-- a deadline, not just a flag: a capture that never receives a key used to
		-- leave every shortcut dead for the rest of the session
		KB.captureAt = os.clock()
		tween(b, 0.12, { BackgroundColor3 = T.accent })
		b.Text = "…"
	end)

	local conn = UserInputService.InputBegan:Connect(function(i)
		if not listening then return end
		-- same deadline the dispatcher uses: a capture nobody answered must not eat
		-- the next key the user presses an hour later
		if not KB.captureAt or os.clock() - KB.captureAt >= 8 then
			listening = false
			KB.listening = false
			KB.captureAt = nil
			tween(b, 0.15, { BackgroundColor3 = T.stroke })
			b.Text = key or "—"
			return
		end
		if i.UserInputType ~= Enum.UserInputType.Keyboard then
			-- a click elsewhere cancels the capture and keeps the previous key
			listening = false
			KB.listening = false
			KB.captureAt = nil
			tween(b, 0.15, { BackgroundColor3 = T.stroke })
			b.Text = key or "—"
			return
		end
		listening = false
		tween(b, 0.15, { BackgroundColor3 = T.stroke })
		apply(i.KeyCode.Name)
		if A.touch then A.touch() end
		-- cleared last and on the next frame: the dispatcher in tail/keybinds.lua is
		-- connected after this handler, so it must still see the capture as active
		task.defer(function()
			KB.listening = false
			KB.captureAt = nil
		end)
	end)
	A.onCleanup(function() conn:Disconnect() end)

	apply(default)
	register(r, name, function(v) apply(v) end, function() return key end)
	registry[#registry].reset = function() apply(default) end
	return { get = function() return key end, row = r, conn = conn }
end
