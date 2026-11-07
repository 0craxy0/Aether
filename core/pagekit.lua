local A = ...
local new, tween, corner, stroke, label = A.new, A.tween, A.corner, A.stroke, A.label
local T, FONT, onCleanup = A.T, A.FONT, A.onCleanup
local motion, sfx = A.motion, A.sfx
local RunService, UserInputService = A.RunService, A.UserInputService
local screen, window, shadow, EL = A.screen, A.window, A.shadow, A.EL
local sidebar, content, accentLinks = A.sidebar, A.content, A.accentLinks
local maskGuis, uiScales, W, H = A.maskGuis, A.uiScales, A.W, A.H

local pages, tabs = {}, {}
A.pages, A.tabs = pages, tabs
A.activeTab = nil

-- pages -------------------------------------------------------
local function tabIndex(name)
	for i, page in ipairs(tabs) do
		if page.btn.Text == name then return i end
	end
	return 1
end

-- Page hooks: a page whose rows are built from config (saved spots, the profile
-- list) has to be told when it becomes visible, and once after the config has
-- loaded. Called at the end of selectPage and from tail/startup.lua's reveal.
A.pageHooks = {}
function A.onPage(fn) A.pageHooks[#A.pageHooks + 1] = fn end
function A.refreshPages(name)
	for _, fn in ipairs(A.pageHooks) do pcall(fn, name) end
end

local function selectPage(name)
	-- an expanded dropdown belongs to the page it was opened on; leaving it open
	-- would also leave the page's canvas taller than the rows it now shows
	if A.closeDropdowns then A.closeDropdowns() end
	-- recolouring the accent re-selects the current tab: that is a repaint, not a trip
	local same = A.activeTab == name
	local dir = tabIndex(name) >= tabIndex(A.activeTab or "") and 1 or -1
	A.activeTab = name
	if not same then sfx("page") end

	for _, page in pairs(pages) do
		local on = page.btn.Text == name
		page.scroll.Visible = on
		-- The bar is the only "you are here" the sidebar has, and it used to be
		-- switched off for every page including the active one, so it never drew.
		page.bar.Visible = on
		if on then
			page.bar.Size = UDim2.fromOffset(2, 0)
			tween(page.bar, 0.28, { Size = UDim2.fromOffset(2, 14) }, Enum.EasingStyle.Back)
			if not same then
				-- the page travels in from the side of the tab you came from,
				-- then its rows settle in one after another
				page.scroll.Position = UDim2.fromOffset(dir * 46, 0)
				page.scale.Scale = 0.97
				tween(page.scroll, 0.34, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quint)
				tween(page.scale, 0.34, { Scale = 1 }, Enum.EasingStyle.Quint)
				pcall(motion.reveal, page.scroll) -- cosmetic: never break a page switch
			end
		end
		tween(page.btn, 0.25, { TextColor3 = on and T.accent or T.muted })
		tween(page.btn, 0.25, { BackgroundTransparency = on and 0.82 or 1, BackgroundColor3 = T.accent })
	end
	-- scroll the sidebar so the tab we just switched to is inside the viewport.
	-- Look the button up from the page list: the loop above scopes `page` to
	-- itself, and reaching for it out here is a nil index at load time.
	for _, page in pairs(pages) do
		if page.btn.Text == name then
			if A.revealTab then pcall(A.revealTab, page.btn) end
			break
		end
	end
	A.refreshPages(name)
end
A.selectPage = selectPage

function A.makePage(name, order)
	local btn = new("TextButton", {
		Text = name, Font = FONT.med, TextSize = 12, TextColor3 = T.muted,
		BackgroundColor3 = T.raised, BackgroundTransparency = 1,
		AutoButtonColor = false, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, Parent = sidebar,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	local bar = new("Frame", { Size = UDim2.fromOffset(2, 14), Position = UDim2.fromOffset(0, 8), BackgroundColor3 = T.accent, BorderSizePixel = 0, Visible = false, Parent = btn }, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	accentLinks[#accentLinks + 1] = { obj = bar, kind = "fill" }

	local scroll = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageColor3 = T.stroke, Visible = false, Parent = content,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	-- its own scale: kept out of uiScales so window rescaling never fights the entrance
	local pageScale = new("UIScale", { Parent = scroll })

	local page = { btn = btn, scroll = scroll, bar = bar, sections = {}, scale = pageScale }

	function page.section(title, sectionOrder)
		local sec = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = sectionOrder * 2, Parent = scroll })
		label({ Text = title, Font = FONT.med, TextSize = 11, TextColor3 = T.muted, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -2, 1, 0), Parent = sec })
		local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = sectionOrder * 2 + 1, Parent = scroll }, {
			new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
		page.sections[#page.sections + 1] = holder
		return holder
	end

	btn.MouseButton1Click:Connect(function() selectPage(name) end)
	btn.MouseEnter:Connect(function()
		if A.activeTab ~= name then tween(btn, 0.12, { TextColor3 = T.text, BackgroundTransparency = 0.7 }) end
	end)
	btn.MouseLeave:Connect(function()
		if A.activeTab ~= name then tween(btn, 0.12, { TextColor3 = T.muted, BackgroundTransparency = 1 }) end
	end)
	pages[name] = page
	tabs[#tabs + 1] = page
	return page
end

-- module config menus -----------------------------------------
local UI = { active = nil, busy = false }
A.UI = UI

-- spring-back target: window, shadow and the open config menu move together
EL.apply = function(pos)
	window.Position = pos
	shadow.Position = pos
	if UI.active then UI.active.frame.Position = pos end
end
EL.endConn = UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		if EL.active then
			EL.active = false
			EL.release()
		end
	end
end)
onCleanup(function() EL.endConn:Disconnect() end)

-- absolute guard: whatever happens, the UI is pulled back fully on screen
EL.guard = RunService.Heartbeat:Connect(function()
	if EL.active or EL.simulating then return end
	local target = window
	if not window.Visible then
		if not UI.active then return end
		target = UI.active.frame
	end
	local fixed = A.clampPos(target.Position, target.AbsoluteSize)
	if fixed ~= target.Position then EL.apply(fixed) end
end)
onCleanup(function() EL.guard:Disconnect() end)

function A.makeConfig(title)
	local frame = new("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = window.Position,
		Size = UDim2.fromOffset(W, H), BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.03, BorderSizePixel = 0,
		GroupTransparency = 1, Visible = false, Parent = screen,
	})
	corner(frame, 11)
	stroke(frame, T.stroke, 0.25)

	local head = new("Frame", { Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Parent = frame })
	local back = new("TextButton", {
		Text = "Back", Font = FONT.med, TextSize = 12, TextColor3 = T.text,
		BackgroundColor3 = T.raised, AutoButtonColor = false, BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(70, 26), Parent = head,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }) })
	back.MouseEnter:Connect(function() tween(back, 0.12, { BackgroundColor3 = T.accent }) end)
	back.MouseLeave:Connect(function() tween(back, 0.12, { BackgroundColor3 = T.raised }) end)
	label({
		Text = title .. "  <font color=\"#79818C\">settings</font>", Font = FONT.bold, TextSize = 15,
		Position = UDim2.fromOffset(98, 0), Size = UDim2.new(1, -112, 1, 0), Parent = head,
	})

	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -28, 1, -76),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke, Parent = frame,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})

	maskGuis[#maskGuis + 1] = frame
	uiScales[#uiScales + 1] = new("UIScale", { Scale = uiScales[1].Scale, Parent = frame })
	local cfg = { frame = frame, scroll = scroll, title = title }

	function cfg.section(name, order)
		local sec = new("Frame", { Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, LayoutOrder = order * 2, Parent = scroll })
		label({ Text = name, Font = FONT.med, TextSize = 11, TextColor3 = T.muted, Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -2, 1, 0), Parent = sec })
		return new("Frame", {
			Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1, LayoutOrder = order * 2 + 1, Parent = scroll,
		}, {
			new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }),
		})
	end

	back.MouseButton1Click:Connect(function() UI.close() end)

	-- drag (keeps the main window + shadow in sync)
	local dragging, startPos, origin
	head.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, origin = true, i.Position, frame.Position
			EL.grab(frame.Position, frame.AbsoluteSize)
		end
	end)
	local c1 = UserInputService.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - startPos
			frame.Position = EL.pos(UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y), frame.AbsoluteSize)
			window.Position = frame.Position
			shadow.Position = frame.Position
		end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	onCleanup(function() c1:Disconnect(); c2:Disconnect() end)

	return cfg
end

local function openConfig(cfg)
	if UI.busy or UI.active then return end
	UI.busy = true
	tween(window, 0.2, { GroupTransparency = 1, Size = UDim2.fromOffset(W * 0.94, H * 0.94) })
	task.delay(0.2, function()
		-- screen gone (unload raced the open): release the lock, or every later
		-- open/close is refused for the rest of the session
		if not screen.Parent then UI.busy = false; return end
		window.Visible = false
		window.Size = UDim2.fromOffset(W, H)
		window.GroupTransparency = 0
		cfg.frame.Position = window.Position
		cfg.frame.Size = UDim2.fromOffset(W * 0.7, H * 0.7)
		cfg.frame.GroupTransparency = 1
		cfg.frame.Visible = true
		cfg.scroll.CanvasPosition = Vector2.zero
		tween(cfg.frame, 0.8, { Size = UDim2.fromOffset(W, H), GroupTransparency = 0 }, Enum.EasingStyle.Elastic)
		UI.active = cfg
		UI.busy = false
	end)
end
A.openConfig = openConfig

function UI.close()
	local cfg = UI.active
	if not cfg or UI.busy then return end
	UI.busy = true
	tween(cfg.frame, 0.2, { GroupTransparency = 1, Size = UDim2.fromOffset(W * 0.94, H * 0.94) })
	task.delay(0.2, function()
		if not screen.Parent then
			UI.busy = false -- same lock as openConfig: never leave the panel stranded
			return
		end
		cfg.frame.Visible = false
		window.Position = cfg.frame.Position
		shadow.Position = window.Position
		window.Size = UDim2.fromOffset(W * 0.7, H * 0.7)
		window.GroupTransparency = 1
		window.Visible = true
		shadow.Visible = true
		tween(window, 0.8, { Size = UDim2.fromOffset(W, H), GroupTransparency = 0 }, Enum.EasingStyle.Elastic)
		UI.active = nil
		UI.busy = false
	end)
end

-- adds a gear button to a toggle row that opens `cfg`
-- The mark used to be two crossed arms - the same glyph the panel uses for
-- "close", at the same weight - so it read as "dismiss this row" and sat on top
-- of the toggle switch. It is now the usual three-slider settings mark, kept
-- clear of the switch, over a pill that only shows itself under the cursor.
local GEAR_KNOB_X = { 8, 14, 10 }

function A.gear(tg, cfg)
	local btn = new("TextButton", {
		Text = "", BackgroundColor3 = T.stroke, BackgroundTransparency = 1,
		AutoButtonColor = false, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -88, 0.5, 0),
		Size = UDim2.fromOffset(22, 22), Parent = tg.row,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	for i = 1, 3 do
		local y = 5 + (i - 1) * 5
		new("Frame", {
			Name = "gearTrack", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(11, y),
			Size = UDim2.fromOffset(11, 1.5), BackgroundColor3 = T.muted, BorderSizePixel = 0, Parent = btn,
		})
		new("Frame", {
			Name = "gearKnob", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(GEAR_KNOB_X[i], y),
			Size = UDim2.fromOffset(4, 4), BackgroundColor3 = T.muted, BorderSizePixel = 0, Parent = btn,
		}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end

	local function paint(col, bg)
		for _, a in ipairs(btn:GetChildren()) do
			if a.Name == "gearTrack" or a.Name == "gearKnob" then tween(a, 0.15, { BackgroundColor3 = col }) end
		end
		tween(btn, 0.15, { BackgroundTransparency = bg })
	end
	btn.MouseEnter:Connect(function() paint(T.text, 0.55) end)
	btn.MouseLeave:Connect(function() paint(T.muted, 1) end)

	btn.MouseButton1Click:Connect(function() openConfig(cfg) end)
	return btn
end

A.stage("3 modules + config menus defined")

