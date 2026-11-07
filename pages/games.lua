local A = ...
local makePage, label, new, rowBase, notify = A.makePage, A.label, A.new, A.rowBase, A.notify
local T, FONT = A.T, A.FONT

-- Games page ------------------------------------------------------------ hub --
-- The loader picks a shelf before it fetches anything (main.lua), so switching
-- here is a restart, not a toggle. Saying that out loud is the difference
-- between a setting and a bug report: the button restarts into the new shelf in
-- the same click, with the config flushed exactly like the updater does it.
local pG = makePage("Games", 9)
local profile = A.game or { name = "Universal", key = "universal", blurb = "" }

local sNow = pG.section("This session", 1)
label({
	Text = string.format("%s profile · place %d", tostring(profile.name), tonumber(A.place or game.PlaceId) or 0),
	Font = FONT.med, TextSize = 12, Size = UDim2.new(1, 0, 0, 18), Parent = sNow,
})
label({
	Text = tostring(profile.blurb or ""),
	TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 34), Parent = sNow,
})

local sList = pG.section("Profiles", 2)

local function restart()
	task.delay(0.6, function()
		if A.updater and A.updater.restart then
			return A.updater.restart()
		end
		A.notify("Games", "restart unavailable - re-execute the loader", "bad")
	end)
end

local function use(key)
	if key == A.profile then return end
	if not A.forceProfile(key) then return end
	notify("Games", "switching to " .. A.games[key].name .. " · restarting", "good")
	restart()
end

for i, p in ipairs(A.gameProfiles or {}) do
	local active = p.key == A.profile
	local row = rowBase(sList, 42)
	row.LayoutOrder = i
	label({
		Text = p.name, Font = FONT.med, TextSize = 12,
		TextColor3 = active and T.accent or T.text,
		Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -110, 0, 16), Parent = row,
	})
	label({
		Text = p.place and ("place " .. p.place) or "any place",
		TextColor3 = T.muted, TextSize = 10,
		Position = UDim2.fromOffset(11, 21), Size = UDim2.new(1, -110, 0, 13), Parent = row,
	})
	local b = new("TextButton", {
		Text = active and "ACTIVE" or "USE", Font = FONT.bold, TextSize = 10,
		TextColor3 = active and T.muted or T.text, BackgroundColor3 = active and T.panel or T.stroke,
		AutoButtonColor = false, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(66, 22), Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	if not active then
		b.MouseEnter:Connect(function() A.tween(b, 0.12, { BackgroundColor3 = T.accent }) end)
		b.MouseLeave:Connect(function() A.tween(b, 0.12, { BackgroundColor3 = T.stroke }) end)
		b.MouseButton1Click:Connect(function()
			A.sfx("tap")
			use(p.key)
		end)
	end
end

local sInfo = pG.section("How this works", 3)
label({
	Text = "Detection follows the place: teleport into a supported game and the loader restarts itself on that shelf. "
		.. "Arsenal and Tesla are tuned - only the modules that make sense for that game are fetched. "
		.. "Universal is the default for anything else: every module in one shelf, none of it calibrated.",
	TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 66), Parent = sInfo,
})
local auto = new("TextButton", {
	Text = "BACK TO AUTO-DETECT", Font = FONT.bold, TextSize = 10, TextColor3 = T.text,
	BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 26), Parent = sInfo,
}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })
auto.MouseButton1Click:Connect(function()
	A.sfx("tap")
	A.clearProfile()
	A.notify("Games", "auto-detect restored · restarting", "good")
	restart()
end)
label({
	Text = "The shelf is decided by place id before the first file is downloaded, so a switch restarts the loader instead of rebuilding pages. A manual choice sticks for this place only - the next teleport returns to auto-detect.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 40), Parent = sInfo,
})
