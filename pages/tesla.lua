local A = ...
-- The Tesla tab exists only where the module does. The loader already filters the
-- file by shelf/detection; this is the same promise made locally, so a mismatch
-- costs a missing tab instead of a nil-index on the first row.
if not A.Tesla then return end
local makePage, toggle, slider, dropdown, button = A.makePage, A.toggle, A.slider, A.dropdown, A.button
local label, new, rowBase = A.label, A.new, A.rowBase
local UserInputService, sfx, tween = A.UserInputService, A.sfx, A.tween
local T, FONT, notify = A.T, A.FONT, A.notify

local TESLA = A.Tesla
local CG, AP = TESLA.gas, TESLA.auto

-- Tesla page ------------------------------------------------------------ tesla --
-- Three things the user can see: what car we think we are in, what number we
-- think cold gas is, and where the auto-pilot thinks it is going. Every row here
-- is a knob over a module that works without the page; the page never holds
-- state of its own except for the widgets.
local pT = makePage("Tesla", 5)

local sVeh = pT.section("Vehicle", 1)
local vehLabel = label({
	Text = "", TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 30), Parent = sVeh,
})
button(sVeh, "Rescan vehicle", "SCAN", function()
	local seat, model = TESLA.vehicle()
	if not model then
		return notify("Vehicle", "sit in the driver's seat first", "bad")
	end
	CG.scan()
	notify("Vehicle", model.Name .. " · " .. (seat.Name or "seat"), "good")
end)

-- ----------------------------------------------------------- attributes --
-- Every number the car keeps that decides how it moves: top speed, acceleration,
-- gravity, grip, boost. The module finds them and renames them; this section is
-- one row each - the friendly name, what it really is, the value it had when it
-- was mapped in the box, and a reset back to that value.
local sAttr = pT.section("Car attributes", 2)
local attrHint = label({
	Text = "Sit in the car and press MAP. Values are the car's own at mapping time. Type a number and press Enter, or click away.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 28), Parent = sAttr,
})
button(sAttr, "Map car attributes", "MAP", function()
	local found = TESLA.attrs.map()
	rebuildAttrs()
	if #found == 0 then
		notify("Attributes", "nothing mapped · sit in the driver's seat first", "bad")
	else
		notify("Attributes", string.format("%d value%s mapped", #found, #found == 1 and "" or "s"), "good")
	end
end)

local attrHolder = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = sAttr,
}, { new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })

local function attrKindText(e)
	if e.kind == "gravity" then return "workspace.Gravity" end
	return tostring(e.name) .. " · " .. (e.kind == "attr" and "attribute" or "value")
end

function rebuildAttrs() -- luacheck: ignore
	for _, c in ipairs(attrHolder:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local list = TESLA.attrs.list
	if #list == 0 then
		label({
			Text = "Nothing mapped yet. Sit in the driver's seat, then MAP.",
			TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 26), Parent = attrHolder,
		})
		return
	end
	for i, e in ipairs(list) do
		local row = rowBase(attrHolder, 40)
		row.LayoutOrder = i
		label({
			Text = e.label, Font = FONT.med, TextSize = 12,
			Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -152, 0, 16), Parent = row,
		})
		label({
			Text = attrKindText(e), TextColor3 = T.muted, TextSize = 9,
			Position = UDim2.fromOffset(11, 21), Size = UDim2.new(1, -152, 0, 13),
			TextTruncate = Enum.TextTruncate.AtEnd, Parent = row,
		})

		-- the value goes in Text, never the placeholder: a hint that disappears the
		-- moment you type is not the value you are editing
		local box = new("TextBox", {
			Name = "value", Text = TESLA.attrs.fmt(e.value), PlaceholderText = "",
			ClearTextOnFocus = false, Font = FONT.med, TextSize = 11, TextColor3 = T.text,
			BackgroundColor3 = T.bg, BorderSizePixel = 0,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -74, 0.5, 0),
			Size = UDim2.fromOffset(62, 24), Parent = row,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0, 5) }),
			new("UIStroke", { Color = T.stroke, Transparency = 0.45, Thickness = 1 }),
		})
		e.box = box

		box.FocusLost:Connect(function()
			local ok, why = TESLA.attrs.set(e, box.Text)
			box.Text = TESLA.attrs.fmt(TESLA.attrs.read(e))
			if ok then
				notify(e.label, "set to " .. box.Text, "good")
			else
				notify(e.label, tostring(why), "bad")
			end
		end)

		local reset = new("TextButton", {
			Text = "Reset", Font = FONT.med, TextSize = 10, TextColor3 = T.muted,
			BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(56, 24), Parent = row,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		reset.MouseEnter:Connect(function() tween(reset, 0.12, { BackgroundColor3 = T.accent, TextColor3 = T.text }) end)
		reset.MouseLeave:Connect(function() tween(reset, 0.12, { BackgroundColor3 = T.stroke, TextColor3 = T.muted }) end)
		reset.MouseButton1Click:Connect(function()
			sfx("tap")
			local ok, why = TESLA.attrs.reset(e)
			box.Text = TESLA.attrs.fmt(TESLA.attrs.read(e))
			notify(e.label, ok and ("reset to " .. box.Text) or tostring(why), ok and "good" or "bad")
		end)
	end
end

-- --------------------------------------------------------------- coins --
-- The stunt coin number from the HUD. The module finds where the game keeps it
-- (leaderstats, a folder, or a player attribute) and writes it; the box shows the
-- real value, not a placeholder, and the line above says where it came from.
local sCoin = pT.section("Stunt coins", 3)
local coinWhere = label({
	Text = "looking for the coin value…", TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 26), Parent = sCoin,
})

local coinRow = rowBase(sCoin, 40)
label({
	Text = "Stunt coins", Font = FONT.med, TextSize = 12,
	Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -152, 0, 16), Parent = coinRow,
})
local coinSub = label({
	Text = "current value", TextColor3 = T.muted, TextSize = 9,
	Position = UDim2.fromOffset(11, 21), Size = UDim2.new(1, -152, 0, 13),
	TextTruncate = Enum.TextTruncate.AtEnd, Parent = coinRow,
})

local coinBox = new("TextBox", {
	Name = "coins", Text = "", PlaceholderText = "",
	ClearTextOnFocus = false, Font = FONT.med, TextSize = 11, TextColor3 = T.text,
	BackgroundColor3 = T.bg, BorderSizePixel = 0,
	TextXAlignment = Enum.TextXAlignment.Center,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -74, 0.5, 0),
	Size = UDim2.fromOffset(62, 24), Parent = coinRow,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 5) }),
	new("UIStroke", { Color = T.stroke, Transparency = 0.45, Thickness = 1 }),
})

local function syncCoins(force)
	if force and not TESLA.coins.entry then TESLA.coins.find() end
	local e = TESLA.coins.entry
	local v = TESLA.coins.read(e)
	if type(v) == "number" then
		e.value = v
		coinSub.Text = "current · " .. tostring(math.floor(v))
		coinWhere.Text = "from " .. TESLA.coins.where(e) .. " · client-side, the server may reset it"
		if UserInputService:GetFocusedTextBox() ~= coinBox then
			local txt = tostring(math.floor(v))
			if coinBox.Text ~= txt then coinBox.Text = txt end
		end
	else
		coinSub.Text = "not found"
		coinWhere.Text = "No coin value on this player yet. Press SCAN while the coin HUD is on screen."
	end
end

local function applyCoins()
	local want = coinBox.Text
	local ok, why = TESLA.coins.set(want)
	if ok then
		notify("Stunt coins", "set to " .. tostring(math.floor(tonumber(want) or 0)), "good")
	else
		notify("Stunt coins", tostring(why), "bad")
	end
	syncCoins()
end

coinBox.FocusLost:Connect(function(enter) if enter then applyCoins() end end)

local coinSet = new("TextButton", {
	Text = "Set", Font = FONT.med, TextSize = 10, TextColor3 = T.text,
	BackgroundColor3 = T.accent, AutoButtonColor = false, BorderSizePixel = 0,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.fromOffset(56, 24), Parent = coinRow,
}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
coinSet.MouseEnter:Connect(function() tween(coinSet, 0.12, { BackgroundColor3 = T.good }) end)
coinSet.MouseLeave:Connect(function() tween(coinSet, 0.12, { BackgroundColor3 = T.accent }) end)
coinSet.MouseButton1Click:Connect(function() sfx("tap"); applyCoins() end)

button(sCoin, "Find the coin value", "SCAN", function()
	local e = TESLA.coins.find()
	syncCoins(true)
	notify("Stunt coins", e and ("found " .. TESLA.coins.where(e)) or "no coin value on this player", e and "good" or "bad")
end)

syncCoins(true)

local sGas = pT.section("Cold gas", 4)
local gasToggle = toggle(sGas, "Infinite cold gas", false, function(v)
	CG.set(v)
	if v and #CG.live == 0 then
		notify("Cold gas", "no gas value found · boost assist can still do it", "bad")
	end
end)
local gasLabel = label({
	Text = "off", TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 28), Parent = sGas,
})
local assistToggle = toggle(sGas, "Boost assist (velocity)", false, function(v) A.Tesla.assist.on = v end)
-- Never restored from config. A build where this defaulted to on has already
-- written "true" into config.json, and replaying that on the next load is exactly
-- how a car freezes before the user has touched anything. It still saves; it just
-- always starts off.
for _, e in ipairs(A.registry) do
	if e.name == "Boost assist (velocity)" then
		e.load = function() assistToggle.set(false, true) end
	end
end
slider(sGas, "Assist top speed", 60, 600, 180, function(v) A.Tesla.assist.top = v end)
label({
	Text = "Off by default and self-limiting: writing velocity on a car the server simulates is a replication round trip per tick, which lags the game. "
		.. "Turn it on only if the page says the gas value is server-owned; it disables itself within 3s if the speed does not actually rise.",
	TextColor3 = T.muted, TextSize = 10, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 44), Parent = sGas,
})
button(sGas, "Scan gas values", "SCAN", function()
	local found = CG.scan()
	if #found == 0 then
		return notify("Cold gas", CG.status, "bad")
	end
	for _, f in ipairs(CG.live) do
		print(string.format("[Aether] gas candidate: %s (%s) = %s", f.name, f.kind, tostring(f.max)))
	end
	notify("Cold gas", string.format("%d value%s held at its maximum", #found, #found == 1 and "" or "s"), "good")
end)

-- ------------------------------------------------------------- auto-pilot --
local rebuildSpots -- forward: the save button refreshes the list below

local sAP = pT.section("Auto-pilot", 5)
local pickToggle = toggle(sAP, "Middle-click to pick destination", false, function(v)
	AP.enabled = v
	if v then notify("Auto-pilot", "middle-click a spot on the map, scroll for height", "good") end
end)
button(sAP, "Pick destination", "PICK", function()
	-- one click should not need a second one to arm: picking implies intent
	if not AP.enabled then pickToggle.set(true) end
	AP.pick()
end)

local heightRow = slider(sAP, "Destination height", -30, 240, 0, function(v) AP.setHeight(v) end)
AP.onHeight = function(h) if heightRow then heightRow.set(h, true) end end

slider(sAP, "Cruise power %", 20, 100, 100, function(v) AP.power = v / 100 end)
slider(sAP, "Stop distance (studs)", 3, 40, 10, function(v) AP.stopRadius = v end)
dropdown(sAP, "Drive method", { "Seat inputs", "Velocity assist" }, "Seat inputs", function(v) AP.method = v end)
toggle(sAP, "Use height while driving", false, function(v) AP.useHeight = v end)
toggle(sAP, "Invert steering", false, function(v) AP.invertSteer = v end)

local apLabel = label({
	Text = "no destination", TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 28), Parent = sAP,
})
button(sAP, "Cancel auto-pilot", "STOP", function()
	if AP.picking then return AP.cancel() end
	AP.stop("stopped")
end)
button(sAP, "Save destination", "SAVE", function()
	local name, why = TESLA.saveSpot()
	if not name then return notify("Auto-pilot", tostring(why), "bad") end
	notify("Auto-pilot", name .. " saved", "good")
	rebuildSpots()
end)

-- ---------------------------------------------------------- saved spots ---
local sSpots = pT.section("Saved spots", 6)
local spotHolder = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1, Parent = sSpots,
}, { new("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }) })

function rebuildSpots() -- luacheck: ignore
	for _, c in ipairs(spotHolder:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local list = TESLA.spots()
	if #list == 0 then
		label({
			Text = "Nothing saved yet. Pick a destination, then Save destination.",
			TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
			Size = UDim2.new(1, 0, 0, 28), Parent = spotHolder,
		})
		return
	end
	for i, rec in ipairs(list) do
		local row = rowBase(spotHolder, 30)
		row.LayoutOrder = i
		label({
			Text = string.format("%s · %d, %d, %d", tostring(rec.name), rec.x, rec.y, rec.z),
			TextColor3 = T.muted, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(11, 0), Size = UDim2.new(1, -84, 1, 0), Parent = row,
		})
		local go = new("TextButton", {
			Text = "DRIVE", Font = FONT.bold, TextSize = 10, TextColor3 = T.text,
			BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
			Size = UDim2.fromOffset(56, 20), Parent = row,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		go.MouseButton1Click:Connect(function()
			A.sfx("tap")
			TESLA.driveTo(rec)
		end)
	end
end
button(sSpots, "Clear saved spots", "CLEAR", function()
	TESLA.clearSpots()
	rebuildSpots()
	notify("Auto-pilot", "saved spots cleared", "good")
end)
rebuildSpots()

A.onPage(function(name)
	if name ~= "Tesla" then return end
	rebuildSpots()
	if #TESLA.attrs.list == 0 then TESLA.attrs.map() end
	rebuildAttrs()
end)

-- one quiet loop keeps the readouts (and the attribute boxes) honest without a
-- connection per label. A box being typed in is left alone - the game can rewrite
-- an attribute under us, but it must not rewrite the half-typed number in the field
local running = true
task.spawn(function()
	while running do
		task.wait(0.4)
		if pT.scroll and pT.scroll.Visible then
			local focused = UserInputService:GetFocusedTextBox()
			for _, e in ipairs(TESLA.attrs.list) do
				local b = e.box
				if b and b.Parent and b ~= focused then
					local now = TESLA.attrs.read(e)
					if type(now) == "number" then
						local txt = TESLA.attrs.fmt(now)
						if b.Text ~= txt then b.Text = txt end
						e.value = now
					end
				end
			end
			syncCoins()
			local seat, model = TESLA.vehicle()
			if model then
				vehLabel.Text = string.format("%s · %s%s", model.Name, seat.Name,
					seat:IsA("VehicleSeat") and "" or " (not a VehicleSeat - auto-pilot will push the assembly)")
				vehLabel.TextColor3 = T.text
			else
				vehLabel.Text = "Not seated. Sit in the driver's seat to find the car."
				vehLabel.TextColor3 = T.muted
			end
			gasLabel.Text = CG.on and CG.summary() or "off"
			gasLabel.TextColor3 = (CG.on and (CG.mirrored or 0) > 0) and T.warn
				or ((CG.on and #CG.live > 0) and T.good or T.muted)
			apLabel.Text = AP.active and AP.status
				or (AP.picking and "picking · scroll for height · Enter to drive · Esc to cancel")
				or AP.status
			apLabel.TextColor3 = AP.active and T.accent or T.muted
		end
	end
end)
A.onCleanup(function() running = false end)
