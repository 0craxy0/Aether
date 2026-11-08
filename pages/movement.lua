local A = ...
local makePage, makeConfig, gear = A.makePage, A.makeConfig, A.gear
local slider, toggle, button = A.slider, A.toggle, A.button
local new, label, drawX = A.new, A.label, A.drawX
local T, FONT = A.T, A.FONT
local fly, charParts, notify = A.fly, A.charParts, A.notify
local WP = A.waypoints

local pMove = makePage("Movement", 2)
local cfgFly = makeConfig("Fly")
local sMove = pMove.section("Flight", 1)
local sFlyCfg = cfgFly.section("Flight", 1)
local flyToggle = toggle(sMove, "Fly", false, function(v)
	if v then fly.start() else fly.stop() end
end)
gear(flyToggle, cfgFly)
slider(sFlyCfg, "Fly speed", 10, 400, 55, function(v) fly.speed = v end)

local sMove2 = pMove.section("Teleport", 2)
button(sMove2, "Teleport to cursor", "GO", A.tpToCursor)
-- Was a button that flipped Anchored and forgot about it, so a reset left you
-- falling with the button still claiming to be on. A.setAnchor keeps the intent.
toggle(sMove2, "Anchor position", false, function(v) A.setAnchor(v) end)
button(sMove2, "Reset character", "RESET", function()
	local _, hum = charParts()
	if hum then hum.Health = 0 end
end)

-- waypoints -------------------------------------------------------------------

local sWp = pMove.section("Waypoints", 3)
local rebuild

local nameInput = A.input(sWp, "Waypoint name", "pads, shop, roof", function(v)
	-- Enter in the field and the SAVE button do the same thing on purpose
	local ok, msg = WP.save(v)
	notify("Waypoints", msg, ok and "good" or "bad")
	rebuild()
end)

button(sWp, "Save current position", "SAVE", function()
	local ok, msg = WP.save(nameInput.get())
	notify("Waypoints", msg, ok and "good" or "bad")
	rebuild()
end)

rebuild = function()
	if not sWp.Parent then return end
	for _, c in ipairs(sWp:GetChildren()) do
		if c.Name == "wpRow" then c:Destroy() end
	end
	local _, _, root = charParts()
	local here = root and root.Position
	for _, w in ipairs(WP.list()) do
		local pos = Vector3.new(w.x, w.y, w.z)
		local row = A.rowBaseRaw(sWp, 40)
		row.Name = "wpRow"

		label({
			Text = w.name, Font = FONT.med, TextSize = 12,
			Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -100, 0, 16), Parent = row,
		})
		label({
			Text = string.format("%.0f, %.0f, %.0f%s", w.x, w.y, w.z,
				here and string.format("  ·  %d studs", math.floor((pos - here).Magnitude)) or ""),
			TextColor3 = T.muted, TextSize = 10,
			Position = UDim2.fromOffset(11, 22), Size = UDim2.new(1, -100, 0, 13), Parent = row,
		})

		local go = new("TextButton", {
			Text = "GO", Font = FONT.bold, TextSize = 10, TextColor3 = T.text,
			BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
			Size = UDim2.fromOffset(52, 22), Parent = row,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		go.MouseEnter:Connect(function() A.tween(go, 0.12, { BackgroundColor3 = T.accent }) end)
		go.MouseLeave:Connect(function() A.tween(go, 0.12, { BackgroundColor3 = T.stroke }) end)
		go.MouseButton1Click:Connect(function()
			local ok, why = WP.go(w.name)
			if not ok then notify("Waypoints", why, "bad") end
		end)

		local del = new("TextButton", {
			Text = "", BackgroundColor3 = T.stroke, AutoButtonColor = false, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -67, 0.5, 0),
			Size = UDim2.fromOffset(22, 22), Parent = row,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
		drawX(del, 9, T.muted)
		del.MouseEnter:Connect(function()
			A.tween(del, 0.12, { BackgroundColor3 = T.bad })
			for _, a in ipairs(del:GetChildren()) do
				if a.Name == "xarm" then A.tween(a, 0.12, { BackgroundColor3 = T.text }) end
			end
		end)
		del.MouseLeave:Connect(function()
			A.tween(del, 0.12, { BackgroundColor3 = T.stroke })
			for _, a in ipairs(del:GetChildren()) do
				if a.Name == "xarm" then A.tween(a, 0.12, { BackgroundColor3 = T.muted }) end
			end
		end)
		del.MouseButton1Click:Connect(function()
			WP.remove(w.name)
			rebuild()
		end)
	end
end

A.onPage(function(name)
	if name == "Movement" then rebuild() end
end)

rebuild()
