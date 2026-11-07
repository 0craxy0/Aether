local A = ...
-- The Tesla tab exists only where the module does. The loader already filters the
-- file by shelf/detection; this is the same promise made locally, so a mismatch
-- costs a missing tab instead of a nil-index on the first row.
if not A.Tesla then return end
local makePage, toggle, slider, dropdown, button = A.makePage, A.toggle, A.slider, A.dropdown, A.button
local label, new, rowBase = A.label, A.new, A.rowBase
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

local sGas = pT.section("Cold gas", 2)
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
toggle(sGas, "Boost assist (velocity)", true, function(v) A.Tesla.assist.on = v end)
slider(sGas, "Assist top speed", 60, 600, 180, function(v) A.Tesla.assist.top = v end)
label({
	Text = "A server-owned gas value (NitroMul and friends) is replicated down, so a local write is overwritten and the bar does nothing. "
		.. "Assist ignores it: while the car is rolling forward it raises the top speed the chassis is allowed to reach.",
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

local sAP = pT.section("Auto-pilot", 3)
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
local sSpots = pT.section("Saved spots", 4)
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

A.onPage(function(name) if name == "Tesla" then rebuildSpots() end end)

-- one quiet loop keeps the three readouts honest without a connection per label
local running = true
task.spawn(function()
	while running do
		task.wait(0.4)
		if pT.scroll and pT.scroll.Visible then
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
