local A = ...

-- Main menu -------------------------------------------------------------------
-- A cover over the window itself, not a card floating on the screen: the panel
-- reveals onto the menu, the menu is the whole panel, and Enter uncovers the
-- sidebar and the pages underneath.
--
-- Settings here is not a link to the Settings tab. The real page's ScrollingFrame
-- is lifted out of the page stack and parented into this cover for as long as the
-- menu is open, then put back exactly where it was. Same rows, same widgets, same
-- state - one implementation, two places to see it - which is the only way a menu
-- copy could ever stay in step with the page it copies.
--
-- Credits resolves 1562524075 at runtime rather than hardcoding a name: the ID is
-- the stable fact, and "{display} ({user})" is what it currently answers to.

local T, FONT = A.T, A.FONT
local new, tween = A.new, A.tween
local Players, onCleanup = A.Players, A.onCleanup
local motion, sfx, UIS = A.motion, A.sfx, A.UserInputService

local OWNER_ID = 1562524075
local win = A.window
if not win then return end

-- Sized from the window, not from a constant: the panel is resizable and a menu
-- with a fixed column looked cramped at 960 and lost in 420. Two thirds of the
-- width is what a menu should be - it is the only thing on screen, so it fills the
-- space instead of sitting in the middle of it.
local COL_W = math.clamp(math.floor((A.W or 580) * 0.66), 300, 520)
local BTN_H = math.clamp(math.floor((A.H or 430) * 0.115), 42, 64)

local cover = new("Frame", {
	Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.bg,
	BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 400, Parent = win,
}, { new("UICorner", { CornerRadius = UDim.new(0, A.windowCorner or 19) }) })

local column = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(COL_W, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, ZIndex = 401, Parent = cover,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function line(props)
	return new("TextLabel", props)
end

local titleLbl = line({
	Text = "AETHER", Font = FONT.bold, TextSize = 32, TextColor3 = T.text,
	BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 40), Parent = column,
})

local buildLbl = line({
	Text = "build " .. tostring(A.build or "?") .. " · rev " .. tostring(A.rev or "?"),
	Font = FONT.reg, TextSize = 11, TextColor3 = T.muted,
	BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 16), Parent = column,
})

local rule = new("Frame", {
	BackgroundColor3 = T.stroke, BackgroundTransparency = 0.35, BorderSizePixel = 0,
	LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 1), Parent = column,
})

-- The same three things every widget in the panel does: lean toward the cursor,
-- ripple where you press, and answer with a sound. Without them the menu read as
-- a different program that happened to share the colours.
local function pointerIn(obj)
	local m = UIS:GetMouseLocation()
	local inset = A.guiInset or 0
	return m.X - obj.AbsolutePosition.X, m.Y - inset - obj.AbsolutePosition.Y
end

local function pageButton(parent, order, caption, onClick)
	local b = new("TextButton", {
		Text = caption, Font = FONT.med, TextSize = 15, TextColor3 = T.text,
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.15, AutoButtonColor = false,
		BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, 0, 0, BTN_H), Parent = parent,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local st = new("UIStroke", {
		Color = T.stroke, Transparency = 0.5, Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b,
	})
	b.MouseEnter:Connect(function()
		tween(b, 0.12, { BackgroundTransparency = 0, TextColor3 = T.accent })
		st.Transparency = 0.15
		if motion then pcall(motion.magnet, b, 30, 3) end
		if sfx then pcall(sfx, "hover") end
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.14, { BackgroundTransparency = 0.15, TextColor3 = T.text })
		st.Transparency = 0.5
	end)
	b.MouseButton1Click:Connect(function()
		if motion then
			local px, py = pointerIn(b)
			pcall(motion.ripple, b, px, py)
		end
		if sfx then pcall(sfx, "tap") end
		pcall(onClick)
	end)
	return b
end

----------------------------------------------------------------------- pages --
local menuPage = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, LayoutOrder = 4, ZIndex = 401, Parent = column,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local creditsPage = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Visible = false, LayoutOrder = 5, ZIndex = 401, Parent = column,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local enterBtn = pageButton(menuPage, 1, "Enter", nil)
local settingsBtn = pageButton(menuPage, 2, "Settings", nil)
local creditsBtn = pageButton(menuPage, 3, "Credits", nil)

line({
	Text = "the tab list is underneath this; the menu does not replace it",
	Font = FONT.reg, TextSize = 11, TextColor3 = T.muted, TextWrapped = true,
	BackgroundTransparency = 1, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 14), Parent = menuPage,
})

-- entrance, the same shape as a page switch: the rows settle in one after another
-- and the wordmark fades up behind them
if motion and motion.reveal then pcall(motion.reveal, menuPage) end
titleLbl.TextTransparency, buildLbl.TextTransparency = 1, 1
rule.BackgroundTransparency = 1
tween(titleLbl, 0.32, { TextTransparency = 0 })
task.delay(0.05, function()
	if buildLbl.Parent then tween(buildLbl, 0.32, { TextTransparency = 0 }) end
end)
task.delay(0.1, function()
	if rule.Parent then tween(rule, 0.4, { BackgroundTransparency = 0.35 }) end
end)

line({
	Text = "CREDITS", Font = FONT.bold, TextSize = 9, TextColor3 = T.muted,
	BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 12), Parent = creditsPage,
})

local ownerLbl = line({
	Text = "resolving…", Font = FONT.med, TextSize = 14, TextColor3 = T.text,
	TextWrapped = true, BackgroundTransparency = 1,
	LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 20), Parent = creditsPage,
})

line({
	Text = "everything else: the people who actually play it",
	Font = FONT.reg, TextSize = 11, TextColor3 = T.muted, TextWrapped = true,
	BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), Parent = creditsPage,
})

pageButton(creditsPage, 4, "Back", function()
	creditsPage.Visible = false
	menuPage.Visible = true
end)

-------------------------------------------------------------------- settings --
-- The whole Settings page, lifted out of the page stack. The page owns a single
-- ScrollingFrame, so moving that frame moves every row, section and widget with
-- it - no second copy, and nothing to keep in sync later.
local settingsView = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
	ZIndex = 402, Parent = cover,
}, {
	new("UIPadding", {
		PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
		PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
	}),
})

local settingsHead = new("Frame", {
	Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, ZIndex = 402, Parent = settingsView,
})

line({
	Text = "SETTINGS", Font = FONT.bold, TextSize = 10, TextColor3 = T.muted,
	TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
	Position = UDim2.fromOffset(2, 0), Size = UDim2.new(1, -90, 1, 0), Parent = settingsHead,
})

local settingsBack = new("TextButton", {
	Text = "Back", Font = FONT.med, TextSize = 11, TextColor3 = T.text,
	BackgroundColor3 = T.raised, BackgroundTransparency = 0.2, AutoButtonColor = false,
	BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
	Size = UDim2.fromOffset(64, 26), Parent = settingsHead,
}, { new("UICorner", { CornerRadius = UDim.new(0, 7) }) })
settingsBack.MouseEnter:Connect(function()
	tween(settingsBack, 0.12, { BackgroundTransparency = 0 })
	if sfx then pcall(sfx, "hover") end
end)
settingsBack.MouseLeave:Connect(function() tween(settingsBack, 0.12, { BackgroundTransparency = 0.2 }) end)
settingsBack.MouseButton1Click:Connect(function()
	if sfx then pcall(sfx, "tap") end
end)

local settingsBody = new("Frame", {
	Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 1, -38),
	BackgroundTransparency = 1, ZIndex = 402, Parent = settingsView,
})

local borrowed = nil

local function borrowSettings()
	if borrowed then return true end
	local page = A.pageSettings
	if not (page and page.scroll) then return false end
	local sc = page.scroll
	borrowed = {
		parent = sc.Parent, size = sc.Size, position = sc.Position,
		visible = sc.Visible, scale = page.scale and page.scale.Scale,
	}
	sc.Parent = settingsBody
	sc.Size = UDim2.fromScale(1, 1)
	sc.Position = UDim2.fromOffset(0, 0)
	sc.Visible = true
	if page.scale then page.scale.Scale = 1 end
	return true
end

local function returnSettings()
	if not borrowed then return end
	local page = A.pageSettings
	local sc = page and page.scroll
	if sc then
		sc.Parent = borrowed.parent
		sc.Size = borrowed.size
		sc.Position = borrowed.position
		sc.Visible = borrowed.visible
		if page.scale and borrowed.scale then page.scale.Scale = borrowed.scale end
	end
	borrowed = nil
end

local function showMenu()
	settingsView.Visible = false
	returnSettings()
	menuPage.Visible = true
	creditsPage.Visible = false
	column.Visible = true
end

------------------------------------------------------------------ behaviour --
local opened = false
local function fadeCover()
	if A.ANIM and A.ANIM.on == false then
		if cover then cover:Destroy() end
		return
	end
	tween(cover, 0.28, { BackgroundTransparency = 1 })
	for _, d in ipairs(cover:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			tween(d, 0.22, { TextTransparency = 1 })
		elseif d:IsA("Frame") and d ~= cover then
			tween(d, 0.22, { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, 0.22, { Transparency = 1 })
		end
	end
	task.delay(0.3, function()
		if cover then cover:Destroy() end
	end)
end

local function open()
	if opened then return end
	opened = true
	returnSettings()
	fadeCover()
end

enterBtn.MouseButton1Click:Connect(open)
settingsBtn.MouseButton1Click:Connect(function()
	if not borrowSettings() then
		A.notify("Menu", "the Settings page is not on this shelf", "bad")
		return
	end
	column.Visible = false
	menuPage.Visible = false
	creditsPage.Visible = false
	settingsView.Visible = true
end)
settingsBack.MouseButton1Click:Connect(showMenu)
creditsBtn.MouseButton1Click:Connect(function()
	menuPage.Visible = false
	creditsPage.Visible = true
end)

----------------------------------------------------------------- name lookup --
local function resolveOwner()
	task.spawn(function()
		local resolved
		local ok, infos = pcall(function() return Players:GetUserInfosByUserIdsAsync({ OWNER_ID }) end)
		if ok and type(infos) == "table" and infos[1] then
			local i = infos[1]
			resolved = string.format("%s (%s)", tostring(i.DisplayName), tostring(i.Username))
		end
		if not resolved then
			local here = Players:GetPlayerByUserId(OWNER_ID)
			if here then resolved = string.format("%s (%s)", here.DisplayName, here.Name) end
		end
		if not resolved then
			local okName, name = pcall(function() return Players:GetNameFromUserIdAsync(OWNER_ID) end)
			if okName and type(name) == "string" then resolved = string.format("%s (%s)", name, name) end
		end
		if ownerLbl and ownerLbl.Parent then ownerLbl.Text = resolved or tostring(OWNER_ID) end
	end)
end
resolveOwner()

onCleanup(function()
	returnSettings()
	if cover and cover.Parent then cover:Destroy() end
end)
