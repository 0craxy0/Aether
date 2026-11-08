local A = ...

-- Things that are not in the README -------------------------------------------
-- Small, harmless, and deliberately undocumented. They are here for the person
-- who pokes at the panel or reads the source; nothing below changes a setting,
-- touches a module, or talks to a network. Every one of them is a comment you
-- can find by searching "easter", which is the point.
--
-- Nothing here is announced in the update notes either: a build that lists its
-- own secrets does not have any.

local T = A.T
local UIS = A.UserInputService
local notify, onCleanup = A.notify, A.onCleanup

-- 1. the word --------------------------------------------------------------
-- Type it anywhere in the panel, with no text box focused, and the accent runs
-- through the palette once and comes back. The buffer is short-lived on purpose:
-- typing one letter a minute should not spell anything.
local WORD = "kernel"
local buf, lastAt = "", 0

local keyConn = UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if UIS:GetFocusedTextBox() then return end

	local s = UIS:GetStringForKeyCode(input.KeyCode)
	if type(s) ~= "string" or #s ~= 1 then return end
	local ch = s:lower()
	if not ch:match("%a") then return end

	local now = os.clock()
	if now - lastAt > 1.6 then buf = "" end
	lastAt = now
	buf = (buf .. ch):sub(-#WORD)
	if buf ~= WORD then return end
	buf = ""

	notify("Aether", "you read the source. respect.", "good")
	task.spawn(function()
		local orig = T.accent
		if not A.setAccent then return end
		for _, hex in ipairs({ "FF375F", "FFD60A", "30D158", "64D2FF" }) do
			pcall(A.setAccent, Color3.fromHex(hex))
			task.wait(0.11)
		end
		pcall(A.setAccent, orig)
	end)
end)
onCleanup(function() keyConn:Disconnect() end)

-- 2. the header ------------------------------------------------------------
-- Seven clicks on the title bar in quick succession shakes the window a little
-- and tells you what the load cost. Discoverable by fidgeting, which is what
-- title bars are for.
local clicks, firstAt = 0, 0
local headerConn = A.header and A.header.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	local now = os.clock()
	if now - firstAt > 4 then
		clicks, firstAt = 0, now
	end
	clicks = clicks + 1
	if clicks < 7 then return end
	clicks = 0

	local win = A.window
	if not win then return end
	local base = win.Position
	task.spawn(function()
		for i = 1, 6 do
			A.tween(win, 0.05, { Position = base + UDim2.fromOffset(i % 2 == 0 and 3 or -3, 0) },
				Enum.EasingStyle.Sine)
			task.wait(0.05)
		end
		win.Position = base
	end)
	notify("Aether", string.format("%s files · %s ms",
		tostring(A.filesLoaded or "?"), tostring(A.loadMs or "?")), "good")
end)
if headerConn then onCleanup(function() headerConn:Disconnect() end) end

-- 3. the search box --------------------------------------------------------
-- A word that means nothing, in a field that means something. Typed in full it
-- answers, once, and stays quiet until you clear the field.
local saidXyzzy = false
if A.searchBox then
	local searchConn = A.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = tostring(A.searchBox.Text or ""):lower()
		if q:find("xyzzy", 1, true) then
			if saidXyzzy then return end
			saidXyzzy = true
			notify("Aether", "nothing happens.", "info")
		elseif q == "" then
			saidXyzzy = false
		end
	end)
	onCleanup(function() searchConn:Disconnect() end)
end

-- 4. the clock -------------------------------------------------------------
-- One minute a day, at 04:20 local time, the panel says so. Once, and only on a
-- client that happens to load in that minute.
task.spawn(function()
	task.wait(1.5)
	local t = os.date("*t")
	if t.hour == 4 and t.min == 20 then
		notify("Aether", "4:20. nice.", "good")
	end
end)
