local A = ...
local new, label = A.new, A.label
local T, FONT = A.T, A.FONT
local toggle, slider, button = A.toggle, A.slider, A.button
local W = A.world
local PAGE = "World"

local pW = A.makePage(PAGE, 5)

-- find & teleport ---------------------------------------------------------------

local sFind = pW.section("Find & teleport", 1)

local results = {}
local doFind, rebuildResults

local query = A.input(sFind, "Name contains", "WinPad, Spawn, Shop", function(v)
	doFind(v)
end)

button(sFind, "Search Workspace", "FIND", function() doFind(query.get()) end)
button(sFind, "Clear results", "CLEAR", function()
	results = {}
	rebuildResults()
end)

doFind = function(q)
	q = tostring(q or "")
	if q == "" then return end
	results = W.search(q, 40)
	rebuildResults()
	if #results == 0 then A.notify("Find", "nothing named like " .. q, "bad") end
end

rebuildResults = function()
	if not sFind.Parent then return end
	for _, c in ipairs(sFind:GetChildren()) do
		if c.Name == "resRow" then c:Destroy() end
	end
	local _, _, root = A.charParts()
	local here = root and root.Position
	for _, hit in ipairs(results) do
		local row = A.rowBaseRaw(sFind, 40)
		row.Name = "resRow"

		label({
			Text = hit.name, Font = FONT.med, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(11, 4), Size = UDim2.new(1, -80, 0, 16), Parent = row,
		})
		label({
			Text = hit.path .. (here and string.format("  ·  %d studs", math.floor((hit.pos - here).Magnitude)) or ""),
			TextColor3 = T.muted, TextSize = 10, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(11, 22), Size = UDim2.new(1, -80, 0, 13), Parent = row,
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
			local ok, why = W.tpTo(hit.pos)
			if not ok then A.notify("Find", why, "bad") end
		end)
	end
end

-- highlight ----------------------------------------------------------------------

local sHl = pW.section("Highlight objects", 2)

toggle(sHl, "Highlight matching parts", false, function(v)
	local ok, why = W.setHighlight(v)
	if not ok then A.notify("Highlight", tostring(why), "bad") end
end)

A.input(sHl, "Highlight name contains", "Coin, Chest, Pad", function(v)
	W.pattern = tostring(v or "")
	W.lastScan = 0 -- rescan on the next frame instead of the next interval
end)

slider(sHl, "Highlight range", 50, 3000, 300, function(v) W.maxDist = v end)
slider(sHl, "Max highlighted", 4, 80, 24, function(v) W.maxObjects = v end)

-- server -------------------------------------------------------------------------

local sInfo = pW.section("This server", 3)
local infoLbl = label({
	Text = "", TextColor3 = T.muted, TextSize = 11, TextWrapped = true,
	Size = UDim2.new(1, 0, 0, 96), Parent = sInfo,
})

local function refreshInfo()
	if not infoLbl.Parent then return end
	local i = W.info()
	infoLbl.Text = table.concat({
		"place " .. i.place,
		"job " .. i.job,
		string.format("players %d · server up %ds · ping %s",
			i.players, i.uptime, i.ping >= 0 and (i.ping .. "ms") or "?"),
		"you " .. i.buddy .. " (" .. i.userId .. ")",
		string.format("%s · build %s · %s shelf", i.executor, i.build, i.profile),
	}, "\n")
end

local running = true
task.spawn(function()
	while running do
		task.wait(2)
		if A.activeTab == PAGE then refreshInfo() end
	end
end)
A.onCleanup(function() running = false end)

A.onPage(function(name)
	if name == PAGE then
		refreshInfo()
		rebuildResults()
	end
end)

refreshInfo()
