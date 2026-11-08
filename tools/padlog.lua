--[[ padlog - where the finish pads of "Send a Global Message" actually are
     place 10164995980

     Execute this in that game and play an obby normally. It samples the
     character every frame and reports three separate things, because any one of
     them on its own is a guess:

       JUMP   a move you did not walk: a finish pad sending you on, or the
              send-back that fires when you skip ahead of your unlocked tier.
              The position the player was at *before* the jump is where the pad
              is - that is the number the hub needs.
       COINS  the moment a coin counter goes up, with the position you were
              standing on when it did. That one is exact, so if the game gives
              the coins while you are on the pad this is the pad position with
              no interpretation needed.
       OBBY   top-level models whose names look like a tier, with their centre,
              so the sends and the send-backs can be read against the layout.

     F8 prints the summary, F9 writes it to Aether/sendglobal-pads.json.
     getgenv().PadLog.report() and .dump() do the same from anywhere: paste the
     JSON (or the printed table) back and the shelf can be written against real
     coordinates instead of guesses.

     Nothing here teleports, touches or fires anything. It only reads your own
     position and your own counters.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LP = Players.LocalPlayer

-- A previous run from the same executor is torn down first, so two samplers
-- cannot double every line in the console.
if getgenv and getgenv().PadLog and getgenv().PadLog.stop then
	pcall(getgenv().PadLog.stop)
end

local CFG = {
	jumpDist = 24,      -- studs moved in one frame that count as "teleported"
	jumpCool = 0.35,    -- seconds between accepted jumps (one per send/send-back)
	nearRadius = 18,    -- studs to look for a pad-shaped part around the takeoff
	clusterDist = 10,   -- two takeoffs this close are the same pad
	coinPoll = 0.2,     -- seconds between counter reads
	reportEvery = 30,   -- seconds between automatic summaries, if anything changed
	file = "Aether/sendglobal-pads.json",
	verbose = true,     -- print every event as it happens
}

local S = {
	samples = 0,
	char = nil,
	root = nil,
	last = nil,
	lastAt = 0,
	events = {},      -- every jump, in order
	clusters = {},    -- takeoffs merged by distance
	coins = {},       -- path -> value, last read
	coinTicks = {},   -- { path, from, to, at, pos }
	obbies = {},
	startedAt = os.clock(),
	dirty = false,
	conns = {},
}

-- small stuff ----------------------------------------------------------------

local function v3(p)
	return string.format("(%.1f, %.1f, %.1f)", p.X, p.Y, p.Z)
end

local function arr(p)
	return string.format("[%.1f, %.1f, %.1f]", p.X, p.Y, p.Z)
end

-- "Workspace.Obbies.Easy.FinishPad", short enough to read and specific enough to
-- find again by hand
local function pathOf(inst)
	local bits = {}
	local node = inst
	for _ = 1, 5 do
		if not node or node == workspace or node == game then break end
		table.insert(bits, 1, node.Name)
		node = node.Parent
	end
	return table.concat(bits, ".")
end

local overlap = OverlapParams.new()
do
	local ok = pcall(function() overlap.FilterType = Enum.RaycastFilterType.Exclude end)
	if not ok then pcall(function() overlap.FilterType = Enum.RaycastFilterType.Blacklist end) end
end

-- Every part within `radius` of `pos`, nearest first. GetPartBoundsInRadius is
-- one call; the descendant scan is only there for an executor or a client that
-- does not expose it.
local function nearby(pos, radius)
	local out = {}
	pcall(function() overlap.FilterDescendantsInstances = { LP.Character } end)
	local ok, parts = pcall(function()
		return workspace:GetPartBoundsInRadius(pos, radius, overlap)
	end)
	if ok and type(parts) == "table" then
		for _, part in ipairs(parts) do
			if part:IsA("BasePart") and not (LP.Character and part:IsDescendantOf(LP.Character)) then
				local d = (part.Position - pos).Magnitude
				if d <= radius then out[#out + 1] = { part = part, dist = d } end
			end
		end
	else
		for _, part in ipairs(workspace:GetDescendants()) do
			if part:IsA("BasePart") and not (LP.Character and part:IsDescendantOf(LP.Character)) then
				local d = (part.Position - pos).Magnitude
				if d <= radius then out[#out + 1] = { part = part, dist = d } end
			end
		end
	end
	table.sort(out, function(a, b) return a.dist < b.dist end)
	return out
end

local function padNames(pos, radius, limit)
	local names, seen = {}, {}
	for _, hit in ipairs(nearby(pos, radius or CFG.nearRadius)) do
		local label = string.format("%s (%s, %.1f studs)", hit.part.Name, pathOf(hit.part), hit.dist)
		if not seen[hit.part.Name .. pathOf(hit.part)] then
			seen[hit.part.Name .. pathOf(hit.part)] = true
			names[#names + 1] = label
			if limit and #names >= limit then break end
		end
	end
	return names
end

-- whose fault a jump probably was: a part named like a finish, if there is one
local FINISH_PATTERN = "finish|pad|goal|end|win|complete|obby|level|checkpoint|coin"
local function finishish(pos)
	for _, hit in ipairs(nearby(pos, CFG.nearRadius)) do
		if hit.part.Name:lower():find(FINISH_PATTERN) or pathOf(hit.part):lower():find(FINISH_PATTERN) then
			return hit.part
		end
	end
	return nil
end

-- character ------------------------------------------------------------------

local function bindCharacter(char)
	-- Same character: nothing to rebind, and re-waiting for a root that is already
	-- missing would pile a ten-second yield onto every frame while you are dead.
	if char == S.char then return end
	S.char = char
	S.root = nil
	S.last = nil
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		local ok, found = pcall(function() return char:WaitForChild("HumanoidRootPart", 10) end)
		root = ok and found or nil
	end
	if root then
		S.root = root
		S.last = root.Position -- never count the spawn itself as a jump
	end
end

S.conns[#S.conns + 1] = LP.CharacterAdded:Connect(function(char)
	task.defer(bindCharacter, char)
end)
if LP.Character then bindCharacter(LP.Character) end

-- clusters -------------------------------------------------------------------

local function clusterFor(pos, toPos)
	for _, c in ipairs(S.clusters) do
		if (c.pos - pos).Magnitude <= CFG.clusterDist then
			c.hits += 1
			S.dirty = true
			for _, t in ipairs(c.landings) do
				if (t.pos - toPos).Magnitude <= CFG.clusterDist then return c end
			end
			c.landings[#c.landings + 1] = { pos = toPos, hits = 1 }
			return c
		end
	end
	local c = {
		pos = pos, hits = 1, first = os.time(),
		names = padNames(pos, CFG.nearRadius, 4),
		finish = finishish(pos),
		landings = { { pos = toPos, hits = 1 } },
	}
	S.clusters[#S.clusters + 1] = c
	S.dirty = true
	return c
end

local function recordJump(from, to, dist)
	local now = os.clock()
	local finish = finishish(from)
	local names = padNames(from, CFG.nearRadius, 4)
	local c = clusterFor(from, to)

	S.events[#S.events + 1] = { from = from, to = to, dist = dist, at = now, names = names }
	if #S.events > 500 then table.remove(S.events, 1) end -- a long session must not grow forever

	if CFG.verbose then
		local line = string.format("[padlog] JUMP %s -> %s  (+%.0f studs)%s",
			v3(from), v3(to), dist,
			finish and ("   finish-ish part: " .. finish.Name) or "")
		print(line)
		for _, n in ipairs(names) do print("           near: " .. n) end
		print(string.format("           this is pad candidate #%d (%d hit%s)",
			table.find(S.clusters, c) or #S.clusters, c.hits, c.hits == 1 and "" or "s"))
	end
end

-- coins ----------------------------------------------------------------------

local function numericValues()
	local out = {}
	local ls = LP:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") and type(v.Value) == "number" then
				out["leaderstats." .. v.Name] = v.Value
			end
		end
	end
	local ok, attrs = pcall(function() return LP:GetAttributes() end)
	if ok and type(attrs) == "table" then
		for name, value in pairs(attrs) do
			if type(value) == "number" then out["@" .. name] = value end
		end
	end
	return out
end

local function pollCoins()
	local now = numericValues()
	for path, value in pairs(now) do
		local before = S.coins[path]
		if before ~= nil and value ~= before then
			local root = S.root
			local pos = root and root.Position
			local delta = value - before
			S.coinTicks[#S.coinTicks + 1] = {
				path = path, from = before, to = value, delta = delta,
				at = os.clock(), pos = pos,
			}
			S.dirty = true
			if CFG.verbose then
				print(string.format("[padlog] COINS %s  %s -> %s  (%+g)%s",
					path, tostring(before), tostring(value), delta,
					pos and ("   standing at " .. v3(pos)) or ""))
				if pos and delta > 0 then
					for _, n in ipairs(padNames(pos, CFG.nearRadius, 3)) do
						print("           near: " .. n)
					end
				end
			end
		end
	end
	S.coins = now
end

-- obby layout ----------------------------------------------------------------

local TIER = "easy|medium|hard|insane|nightmare|normal|extreme|tier|stage|level"
local function scanObbies()
	local out = {}
	for _, m in ipairs(workspace:GetChildren()) do
		local name = m.Name
		if name:lower():find(TIER) then
			local ok, cf, size = pcall(function() return m:GetBoundingBox() end)
			out[#out + 1] = {
				name = name,
				class = m.ClassName,
				center = (ok and cf and cf.Position) or nil,
				size = (ok and size) or nil,
			}
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	S.obbies = out
	return out
end

-- sampling -------------------------------------------------------------------

local function sample()
	S.samples += 1
	local root = S.root
	if not root or not root.Parent then
		-- respawning, or a character that was still assembling when this started:
		-- retry the bind, but at most once a second, never once a frame
		local now = os.clock()
		if LP.Character and (not S.bindAt or now - S.bindAt > 1) then
			S.bindAt = now
			S.char = nil -- force bindCharacter to look again
			bindCharacter(LP.Character)
		end
		return
	end
	local p = root.Position
	local prev = S.last
	S.last = p
	if not prev then return end
	local dist = (p - prev).Magnitude
	if dist < CFG.jumpDist then return end
	local now = os.clock()
	if now - S.lastAt < CFG.jumpCool then return end
	S.lastAt = now
	recordJump(prev, p, dist)
end

S.conns[#S.conns + 1] = RunService.Heartbeat:Connect(sample)

local coinThread = task.spawn(function()
	while true do
		task.wait(CFG.coinPoll)
		local ok, err = pcall(pollCoins)
		if not ok then warn("[padlog] coin poll: " .. tostring(err)) end
	end
end)

-- report ---------------------------------------------------------------------

local function report()
	print("[padlog] ---------------- summary ----------------")
	print(string.format("[padlog] %d samples over %.0fs, %d jumps, %d pad candidate%s",
		S.samples, os.clock() - S.startedAt, #S.events,
		#S.clusters, #S.clusters == 1 and "" or "s"))

	if #S.clusters == 0 then
		print("[padlog] no jumps yet. If the game only ever nudges you a few studs,")
		print("[padlog] lower CFG.jumpDist and run it again.")
	else
		local order = {}
		for i, c in ipairs(S.clusters) do order[#order + 1] = { i = i, c = c } end
		table.sort(order, function(a, b) return a.c.hits > b.c.hits end)
		for _, entry in ipairs(order) do
			local c = entry.c
			print(string.format("[padlog] %d) pad at %s   %d hit%s",
				entry.i, v3(c.pos), c.hits, c.hits == 1 and "" or "s"))
			if c.finish then
				print(string.format("      finish-ish part: %s (%s)", c.finish.Name, pathOf(c.finish)))
			end
			for _, n in ipairs(c.names) do print("      near: " .. n) end
			for _, t in ipairs(c.landings) do
				print(string.format("      sent to %s (%d)", v3(t.pos), t.hits))
			end
		end
	end

	if #S.coinTicks > 0 then
		local seen, paths = {}, {}
		for _, t in ipairs(S.coinTicks) do
			if not seen[t.path] then
				seen[t.path] = true
				paths[#paths + 1] = t.path
			end
		end
		print("[padlog] coin counters seen: " .. table.concat(paths, ", "))
		for _, t in ipairs(S.coinTicks) do
			print(string.format("[padlog]   %s %+g at %s%s",
				t.path, t.delta, t.pos and v3(t.pos) or "(no position)",
				t.pos and ("  near " .. (padNames(t.pos, 10, 1)[1] or "nothing")) or ""))
		end
	else
		print("[padlog] no coin counter moved. Leaderstats and player attributes were")
		print("[padlog] watched; if the number lives somewhere else, say where it is.")
	end

	if #S.obbies > 0 then
		print("[padlog] tier-shaped models in Workspace:")
		for _, o in ipairs(S.obbies) do
			print(string.format("[padlog]   %s (%s) %s", o.name, o.class, o.center and v3(o.center) or "(no bounds)"))
		end
	end
	print("[padlog] -------------------------------------------")
end

local function dump()
	local payload = {
		place = game.PlaceId,
		at = tostring(os.time()),
		samples = S.samples,
		pads = {},
		coinTicks = {},
		obbies = {},
	}
	-- info lookup yields and can fail; the dump is worth more than the name
	pcall(function()
		payload.placeName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name
	end)
	for _, c in ipairs(S.clusters) do
		local landings = {}
		for _, t in ipairs(c.landings) do landings[#landings + 1] = arr(t.pos) end
		payload.pads[#payload.pads + 1] = {
			pos = arr(c.pos), hits = c.hits,
			finish = c.finish and pathOf(c.finish) or nil,
			near = c.names, landings = landings,
		}
	end
	for _, t in ipairs(S.coinTicks) do
		payload.coinTicks[#payload.coinTicks + 1] = {
			path = t.path, from = t.from, to = t.to, delta = t.delta,
			pos = t.pos and arr(t.pos) or nil,
		}
	end
	for _, o in ipairs(S.obbies) do
		payload.obbies[#payload.obbies + 1] = { name = o.name, center = o.center and arr(o.center) or nil }
	end
	local ok, json = pcall(function() return HttpService:JSONEncode(payload) end)
	if not ok then return nil, json end
	if type(writefile) ~= "function" then
		print("[padlog] writefile is unavailable here, so the JSON is below")
		print(json)
		return json
	end
	if type(makefolder) == "function" then pcall(makefolder, "Aether") end
	local okWrite, err = pcall(writefile, CFG.file, json)
	if not okWrite then
		print("[padlog] could not write " .. CFG.file .. ": " .. tostring(err))
		print(json)
		return nil, err
	end
	print("[padlog] wrote " .. CFG.file)
	S.dirty = false
	return json
end

-- auto summary: only when something new came in, so the console stays readable
local reportThread = task.spawn(function()
	while true do
		task.wait(CFG.reportEvery)
		if S.dirty then
			S.dirty = false
			pcall(report)
		end
	end
end)

-- hud ------------------------------------------------------------------------

local hudText
do
	pcall(function()
		local host = (gethui and gethui()) or LP:FindFirstChild("PlayerGui") or game:GetService("CoreGui")
		local gui = Instance.new("ScreenGui")
		gui.Name = "PadLog"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 400
		local box = Instance.new("Frame")
		box.AnchorPoint = Vector2.new(0, 1)
		box.Position = UDim2.new(0, 14, 1, -14)
		box.Size = UDim2.fromOffset(250, 52)
		box.BackgroundColor3 = Color3.fromHex("1C1C1E")
		box.BackgroundTransparency = 0.12
		box.BorderSizePixel = 0
		box.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 9)
		corner.Parent = box
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromHex("38383A")
		stroke.Transparency = 0.4
		stroke.Parent = box
		hudText = Instance.new("TextLabel")
		hudText.BackgroundTransparency = 1
		hudText.Position = UDim2.fromOffset(12, 8)
		hudText.Size = UDim2.new(1, -24, 0, 16)
		hudText.Font = Enum.Font.GothamMedium
		hudText.TextSize = 12
		hudText.TextColor3 = Color3.new(1, 1, 1)
		hudText.TextXAlignment = Enum.TextXAlignment.Left
		hudText.Text = "padlog"
		hudText.Parent = box
		local sub = Instance.new("TextLabel")
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromOffset(12, 26)
		sub.Size = UDim2.new(1, -24, 0, 16)
		sub.Font = Enum.Font.Gotham
		sub.TextSize = 11
		sub.TextColor3 = Color3.fromHex("98989D")
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Text = "F8 report  ·  F9 save"
		sub.Parent = box
		gui.Parent = host
		S.hud = gui
		S.hudText = hudText
	end)
end

local hudThread = task.spawn(function()
	while true do
		task.wait(0.25)
		if S.hudText and S.hudText.Parent then
			S.hudText.Text = string.format("%d samples · %d jumps · %d pad%s",
				S.samples, #S.events, #S.clusters, #S.clusters == 1 and "" or "s")
		end
	end
end)

-- keys -----------------------------------------------------------------------

S.conns[#S.conns + 1] = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.F8 then
		pcall(report)
	elseif input.KeyCode == Enum.KeyCode.F9 then
		pcall(dump)
	end
end)

-- api ------------------------------------------------------------------------

local API = {
	report = report,
	dump = dump,
	config = CFG,
	state = S,
	stop = function()
		for _, conn in ipairs(S.conns) do pcall(function() conn:Disconnect() end) end
		S.conns = {}
		for _, thread in ipairs({ coinThread, reportThread, hudThread }) do
			pcall(task.cancel, thread)
		end
		if S.hud then pcall(function() S.hud:Destroy() end) end
		if getgenv and getgenv().PadLog == API then getgenv().PadLog = nil end
		print("[padlog] stopped")
	end,
}
if getgenv then getgenv().PadLog = API end

scanObbies()
print(string.format("[padlog] watching place %d  ·  0 samples so far", game.PlaceId))
print("[padlog] play an obby. F8 reports, F9 saves to " .. CFG.file)
if #S.obbies > 0 then
	print(string.format("[padlog] %d tier-shaped models found in Workspace", #S.obbies))
end
