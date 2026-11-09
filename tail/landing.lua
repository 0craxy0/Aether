local A = ...

-- Main menu -------------------------------------------------------------------
-- A cover over the window itself, not a card floating on the screen: the panel
-- reveals onto the menu, the menu is the whole panel, and Enter is what uncovers
-- the sidebar and the pages underneath. Nothing here resizes or hides the window -
-- it is the same window, with a full-size sheet on top of it.
--
-- Settings is a shortcut into the real page, not a second copy of it, so the tab
-- stays exactly where it was and both routes land on the same screen.
--
-- Credits resolves 1562524075 at runtime rather than hardcoding a name: the ID is
-- the stable fact, and "{display} ({user})" is what it currently answers to.

local T, FONT = A.T, A.FONT
local new, corner, stroke, tween = A.new, A.corner, A.stroke, A.tween
local Players, onCleanup = A.Players, A.onCleanup

local OWNER_ID = 1562524075
local win = A.window
if not win then return end

local cover = new("Frame", {
	Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundColor3 = T.bg,
	BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 400, Parent = win,
}, { new("UICorner", { CornerRadius = UDim.new(0, A.windowCorner or 19) }) })

-- everything the menu shows lives in this column, centred in the cover
local column = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(260, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, ZIndex = 401, Parent = cover,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function line(props)
	return new("TextLabel", props)
end

line({
	Text = "AETHER", Font = FONT.bold, TextSize = 26, TextColor3 = T.text,
	BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 32), Parent = column,
})

line({
	Text = "build " .. tostring(A.build or "?") .. " · rev " .. tostring(A.rev or "?"),
	Font = FONT.reg, TextSize = 10, TextColor3 = T.muted,
	BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), Parent = column,
})

new("Frame", {
	BackgroundColor3 = T.stroke, BackgroundTransparency = 0.35, BorderSizePixel = 0,
	LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 1), Parent = column,
})

-- pages ---------------------------------------------------------------------
local menuPage = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, ZIndex = 401, Parent = column,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local creditsPage = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Visible = false, ZIndex = 401, Parent = column,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function pageButton(parent, order, caption, onClick)
	local b = new("TextButton", {
		Text = caption, Font = FONT.med, TextSize = 13, TextColor3 = T.text,
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.15, AutoButtonColor = false,
		BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 40), Parent = parent,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local st = new("UIStroke", {
		Color = T.stroke, Transparency = 0.5, Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b,
	})
	b.MouseEnter:Connect(function()
		tween(b, 0.12, { BackgroundTransparency = 0, TextColor3 = T.accent })
		st.Transparency = 0.15
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.14, { BackgroundTransparency = 0.15, TextColor3 = T.text })
		st.Transparency = 0.5
	end)
	b.MouseButton1Click:Connect(function() pcall(onClick) end)
	return b
end

local enterBtn = pageButton(menuPage, 1, "Enter", nil)
local settingsBtn = pageButton(menuPage, 2, "Settings", nil)
local creditsBtn = pageButton(menuPage, 3, "Credits", nil)

line({
	Text = "the tab list is underneath this; the menu does not replace it",
	Font = FONT.reg, TextSize = 10, TextColor3 = T.muted, TextWrapped = true,
	BackgroundTransparency = 1, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 14), Parent = menuPage,
})

-- credits page
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
	Font = FONT.reg, TextSize = 10, TextColor3 = T.muted, TextWrapped = true,
	BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), Parent = creditsPage,
})

pageButton(creditsPage, 4, "Back", function()
	creditsPage.Visible = false
	menuPage.Visible = true
end)

-- behaviour -----------------------------------------------------------------
local opened = false
local function open(page)
	if opened then return end
	opened = true
	if page and A.selectPage then pcall(A.selectPage, page) end

	-- the cover fades rather than cuts, so the sidebar arrives as a reveal
	if A.ANIM and A.ANIM.on == false then
		cover:Destroy()
		return
	end
	tween(cover, 0.28, { BackgroundTransparency = 1 })
	local kids = cover:GetDescendants()
	for _, d in ipairs(kids) do
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

enterBtn.MouseButton1Click:Connect(function() open(nil) end)
settingsBtn.MouseButton1Click:Connect(function() open("Settings") end)
creditsBtn.MouseButton1Click:Connect(function()
	menuPage.Visible = false
	creditsPage.Visible = true
end)

-- name lookup ---------------------------------------------------------------
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
	if cover and cover.Parent then cover:Destroy() end
end)
