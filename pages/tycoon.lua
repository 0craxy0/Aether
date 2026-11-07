local A = ...

-- The page only exists on this game's shelf: main.lua filters the file list by
-- profile, and this guard is the second half of that - a page built without its
-- module would be a tab full of dead controls.
if not A.tycoon then return end

local makePage, label, new, rowBase, notify = A.makePage, A.label, A.new, A.rowBase, A.notify
local toggle, button, tween, sfx = A.toggle, A.button, A.tween, A.sfx
local T, FONT, UserInputService = A.T, A.FONT, A.UserInputService
local TY = A.tycoon

local pT = makePage("Internet Tycoon", 5)

-- money -----------------------------------------------------------------------
local sMoney = pT.section("Money", 1)
local moneyWhere = label({
	Text = "looking for the balance…", TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 26), Parent = sMoney,
})

local balanceRow = rowBase(sMoney, 40)
label({
	Text = "Balance", Font = FONT.med, TextSize = 12,
	Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -152, 0, 16), Parent = balanceRow,
})
local balanceSub = label({
	Text = "current value", TextColor3 = T.muted, TextSize = 9,
	Position = UDim2.fromOffset(11, 21), Size = UDim2.new(1, -152, 0, 13),
	TextTruncate = Enum.TextTruncate.AtEnd, Parent = balanceRow,
})

local moneyBox = new("TextBox", {
	Name = "money", Text = "", PlaceholderText = "",
	ClearTextOnFocus = false, Font = FONT.med, TextSize = 11, TextColor3 = T.text,
	BackgroundColor3 = T.bg, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -74, 0.5, 0),
	Size = UDim2.fromOffset(62, 24), Parent = balanceRow,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 5) }),
	new("UIStroke", { Color = T.stroke, Transparency = 0.45, Thickness = 1 }),
})

local function moneyText(v)
	if type(v) ~= "number" then return "" end
	return tostring(math.floor(v))
end

local function syncMoney(force)
	if force and not TY.money.entry then TY.money.find() end
	local e = TY.money.entry
	local v = TY.money.read(e)
	if type(v) == "number" then
		e.value = v
		balanceSub.Text = "current · " .. moneyText(v)
		moneyWhere.Text = "from " .. TY.money.where(e) .. (TY.money.lockOn and " · locked" or "")
		if UserInputService:GetFocusedTextBox() ~= moneyBox then
			local txt = moneyText(v)
			if moneyBox.Text ~= txt then moneyBox.Text = txt end
		end
	else
		balanceSub.Text = "not found"
		moneyWhere.Text = "No balance on this player yet. Press SCAN once the money HUD has drawn."
	end
end

local function setMoney(n)
	local ok, why = TY.money.set(n)
	if ok then
		notify("Money", "set to " .. moneyText(tonumber(n) or 0), "good")
	else
		notify("Money", tostring(why), "bad")
	end
	syncMoney()
end

moneyBox.FocusLost:Connect(function(enter) if enter then setMoney(moneyBox.Text) end end)

local moneySet = new("TextButton", {
	Text = "Set", Font = FONT.med, TextSize = 10, TextColor3 = T.text,
	BackgroundColor3 = T.accent, AutoButtonColor = false, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(56, 24), Parent = balanceRow,
}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
moneySet.MouseEnter:Connect(function() tween(moneySet, 0.12, { BackgroundColor3 = T.good }) end)
moneySet.MouseLeave:Connect(function() tween(moneySet, 0.12, { BackgroundColor3 = T.accent }) end)
moneySet.MouseButton1Click:Connect(function() sfx("tap"); setMoney(moneyBox.Text) end)

toggle(sMoney, "Keep it there", false, function(v)
	if v then
		local ok, why = TY.money.lock(true, moneyBox.Text)
		if not ok then
			notify("Money", tostring(why), "bad")
			return
		end
		notify("Money", "locked at " .. moneyText(tonumber(moneyBox.Text) or 0), "good")
	else
		TY.money.lock(false)
		notify("Money", "lock off", "good")
	end
	syncMoney()
end)

button(sMoney, "Find the balance", "SCAN", function()
	local e = TY.money.find()
	syncMoney(true)
	notify("Money", e and ("found " .. TY.money.where(e)) or "no balance on this player", e and "good" or "bad")
end)

label({
	Text = "A tycoon reconciles money on the server. The write lands on your client's copy, and it is the copy the HUD reads - "
		.. "\"Keep it there\" re-applies it when the game overwrites it, which is the only part of this a client can own.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 40), Parent = sMoney,
})

-- thunderstorms ----------------------------------------------------------------
local sStorm = pT.section("Thunderstorms", 2)
label({
	Text = "Finds every weather value this game keeps where a client can see it - a storm flag, a thunder chance, a rain state - "
		.. "and pins it to calm. Lightning and thunder effects already running are switched off, not deleted, so turning this "
		.. "off puts the sky back.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 46), Parent = sStorm,
})

local stormStatus = label({
	Text = "off", TextColor3 = T.muted, TextSize = 10,
	Size = UDim2.new(1, 0, 0, 16), Parent = sStorm,
})

local stormList = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = sStorm,
}, { new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function showControls()
	for _, c in ipairs(stormList:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local list = TY.storm.controls
	if #list == 0 then
		label({
			Text = "No weather value found yet. Press SCAN with the storm visible.",
			TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 24), Parent = stormList,
		})
		return
	end
	for i = 1, math.min(#list, 6) do
		local e = list[i]
		label({
			Text = string.format("%s = %s", tostring(e.name), tostring(e.value)),
			TextColor3 = T.muted, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
			LayoutOrder = i, Size = UDim2.new(1, 0, 0, 14), Parent = stormList,
		})
	end
end

local function syncStorm()
	stormStatus.Text = TY.storm.status()
	showControls()
end

toggle(sStorm, "Block thunderstorms", false, function(v)
	TY.storm.set(v)
	if v then
		notify("Thunderstorms", TY.storm.status(), "good")
	else
		notify("Thunderstorms", "off · effects restored", "good")
	end
	syncStorm()
end)

button(sStorm, "Find the weather controls", "SCAN", function()
	local found = TY.storm.find()
	if TY.storm.on then TY.storm.apply() end
	syncStorm()
	notify("Thunderstorms", string.format("%d control%s found", #found, #found == 1 and "" or "s"), #found > 0 and "good" or "bad")
end)

button(sStorm, "Calm the sky now", "CALM", function()
	local wrote = TY.storm.apply()
	local swept = TY.storm.sweep()
	syncStorm()
	notify("Thunderstorms", string.format("%d value%s pinned · %d effect%s off", wrote, wrote == 1 and "" or "s", swept, swept == 1 and "" or "s"), "good")
end)

label({
	Text = "The storm's damage is the server's decision. Pinning the sky keeps your client calm and stops a new storm being started "
		.. "from here; towers the server has already broken stay broken.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 40), Parent = sStorm,
})

-- one loop for both readouts; typing is never overwritten
syncMoney(true)
TY.storm.find()
syncStorm()

local running = true
task.spawn(function()
	while running do
		task.wait(0.5)
		if pT.scroll and pT.scroll.Visible then
			syncMoney()
			stormStatus.Text = TY.storm.status()
		end
	end
end)
A.onCleanup(function() running = false end)
