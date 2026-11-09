local A = ...

-- Main menu -------------------------------------------------------------------
-- The panel does not appear on its own any more: the loading bar finishes and this
-- takes the stage - wordmark, three choices - and Enter is what actually opens the
-- hub. Settings is a shortcut into the real page, not a second copy of it, so the
-- tab stays exactly where it was and both routes land on the same screen.
--
-- Credits resolves 1562524075 at runtime rather than hardcoding a name: the ID is
-- the stable fact, and "{display} ({user})" is what it currently answers to.

local T, FONT = A.T, A.FONT
local new, corner, stroke, tween = A.new, A.corner, A.stroke, A.tween
local Players, onCleanup = A.Players, A.onCleanup

local OWNER_ID = 1562524075

local root = new("Frame", {
	Name = "MainMenu", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	ZIndex = 2000, Active = false, Parent = A.screen,
})

local backdrop = new("Frame", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2000, Parent = root,
})

local card = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(300, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundColor3 = T.bg, BackgroundTransparency = 0.03, BorderSizePixel = 0,
	ZIndex = 2001, Parent = root,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 14) }),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 20), PaddingBottom = UDim.new(0, 18),
		PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 20),
	}),
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
stroke(card, T.stroke, 0.3)

local function text(props)
	return new("TextLabel", props)
end

text({
	Text = "AETHER", Font = FONT.bold, TextSize = 22, TextColor3 = T.text,
	BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 26), Parent = card,
})

text({
	Text = "build " .. tostring(A.build or "?") .. " · rev " .. tostring(A.rev or "?"),
	Font = FONT.reg, TextSize = 10, TextColor3 = T.muted,
	BackgroundTransparency = 1, LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 14), Parent = card,
})

new("Frame", {
	BackgroundColor3 = T.stroke, BackgroundTransparency = 0.35, BorderSizePixel = 0,
	LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 1), Parent = card,
})

local function menuButton(order, caption, onClick)
	local b = new("TextButton", {
		Text = caption, Font = FONT.med, TextSize = 13, TextColor3 = T.text,
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.15, AutoButtonColor = false,
		BorderSizePixel = 0, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 38), Parent = card,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })
	local bStroke = new("UIStroke", {
		Color = T.stroke, Transparency = 0.5, Thickness = 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b,
	})
	b.MouseEnter:Connect(function()
		tween(b, 0.12, { BackgroundTransparency = 0, TextColor3 = T.accent })
		bStroke.Transparency = 0.15
	end)
	b.MouseLeave:Connect(function()
		tween(b, 0.14, { BackgroundTransparency = 0.15, TextColor3 = T.text })
		bStroke.Transparency = 0.5
	end)
	b.MouseButton1Click:Connect(function()
		if A.sfx and A.sfx.click then pcall(A.sfx.click) end
		pcall(onClick)
	end)
	return b
end

-- credits page --------------------------------------------------------------
local credits = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Visible = false, ZIndex = 2002, Parent = card,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

text({
	Text = "CREDITS", Font = FONT.bold, TextSize = 9, TextColor3 = T.muted,
	BackgroundTransparency = 1, LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 12), Parent = credits,
})

local ownerLbl = text({
	Text = "resolving…", Font = FONT.med, TextSize = 13, TextColor3 = T.text,
	TextWrapped = true, BackgroundTransparency = 1,
	LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), Parent = credits,
})

text({
	Text = "everything else: the people who actually play it",
	Font = FONT.reg, TextSize = 10, TextColor3 = T.muted, TextWrapped = true,
	BackgroundTransparency = 1, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), Parent = credits,
})

local backBtn = new("TextButton", {
	Text = "Back", Font = FONT.med, TextSize = 12, TextColor3 = T.muted,
	BackgroundColor3 = T.raised, BackgroundTransparency = 0.15, AutoButtonColor = false,
	BorderSizePixel = 0, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 32), Parent = credits,
}, { new("UICorner", { CornerRadius = UDim.new(0, 8) }) })

-- menu page ----------------------------------------------------------------
local menu = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, ZIndex = 2002, Parent = card,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local enterBtn = menuButton(1, "Enter", nil)
local settingsBtn = menuButton(2, "Settings", nil)
local creditsBtn = menuButton(3, "Credits", nil)

text({
	Text = "the panel stays on the tab list once you are in",
	Font = FONT.reg, TextSize = 10, TextColor3 = T.muted, TextWrapped = true,
	BackgroundTransparency = 1, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 14), Parent = menu,
})

-- behaviour -----------------------------------------------------------------
local resolvedName
local function resolveOwner()
	task.spawn(function()
		local ok, infos = pcall(function()
			return Players:GetUserInfosByUserIdsAsync({ OWNER_ID })
		end)
		if ok and type(infos) == "table" and infos[1] then
			local i = infos[1]
			resolvedName = string.format("%s (%s)", tostring(i.DisplayName), tostring(i.Username))
		end
		if not resolvedName then
			local here = Players:GetPlayerByUserId(OWNER_ID)
			if here then
				resolvedName = string.format("%s (%s)", here.DisplayName, here.Name)
			end
		end
		if not resolvedName then
			local okName, name = pcall(function() return Players:GetNameFromUserIdAsync(OWNER_ID) end)
			if okName and type(name) == "string" then
				resolvedName = string.format("%s (%s)", name, name)
			end
		end
		if ownerLbl and ownerLbl.Parent then
			ownerLbl.Text = resolvedName or tostring(OWNER_ID)
		end
	end)
end
resolveOwner()

local opened = false
local function open(page)
	if opened then return end
	opened = true

	local win, shadow = A.window, A.shadow
	if win then
		win.Visible = true
		win.GroupTransparency = 1
		tween(win, 0.35, { GroupTransparency = 0 })
	end
	if shadow then
		local alpha = shadow:GetAttribute("baseTransparency")
		shadow.Visible = true
		if alpha then shadow.ImageTransparency = 1; tween(shadow, 0.35, { ImageTransparency = alpha }) end
	end

	if page and A.selectPage then pcall(A.selectPage, page) end

	tween(backdrop, 0.25, { BackgroundTransparency = 1 })
	tween(card, 0.22, { BackgroundTransparency = 1 })
	task.delay(0.28, function()
		if root then root:Destroy() end
	end)
end

enterBtn.MouseButton1Click:Connect(function() open(nil) end)
settingsBtn.MouseButton1Click:Connect(function() open("Settings") end)
creditsBtn.MouseButton1Click:Connect(function()
	menu.Visible = false
	credits.Visible = true
end)
backBtn.MouseButton1Click:Connect(function()
	credits.Visible = false
	menu.Visible = true
end)

-- takeover ------------------------------------------------------------------
-- startup.lua still owns the reveal: it decides when the load is finished and
-- plays its own entrance. This waits for that moment, then hides the panel and
-- puts the menu where it was. Doing it the other way round would mean fighting
-- the elastic tween.
task.spawn(function()
	while A.screen and not A.loadingDone do task.wait(0.05) end
	task.wait(0.05)
	if not root.Parent then return end

	local win, shadow = A.window, A.shadow
	if shadow then
		-- what the reveal left it at, so Enter can restore exactly that
		shadow:SetAttribute("baseTransparency", shadow.ImageTransparency)
		shadow.Visible = false
	end
	if win then
		win.Visible = false
		win.GroupTransparency = 0
	end

	tween(backdrop, 0.4, { BackgroundTransparency = 0.45 })
	card.BackgroundTransparency = 0.03
end)

onCleanup(function()
	if root and root.Parent then root:Destroy() end
end)
