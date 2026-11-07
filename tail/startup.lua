local A = ...
local tween, notify, sfx, label = A.tween, A.notify, A.sfx, A.label
local T = A.T
local window, shadow, UI = A.window, A.shadow, A.UI
local closeBtn, searchBox = A.closeBtn, A.searchBox
local keybinds = A.keybinds
local UserInputService = A.UserInputService

-- getgenv().AetherDebug = true before executing prints what every shortcut resolves
-- to and what the show/hide decided, so a broken bind is diagnosable from the console
local DEBUG = getgenv and getgenv().AetherDebug == true
local shadowAlpha = shadow.ImageTransparency -- restore what core/window.lua chose

-- show / hide ----------------------------------------------------
local hidden = false
local hiddenTarget = nil
local toggleRetry = false

local function bindName(action)
	for k, n in pairs(keybinds) do
		if n == action then return k end
	end
end

local function anyVisible()
	if window.Visible then return true end
	if UI.active and UI.active.frame.Visible then return true end
	return false
end

function A.toggleUI()
	if UI.busy then
		-- A config menu is mid-transition. Dropping the press here was the difference
		-- between "the panel is open" and "the panel can never open again", since this
		-- is also the only control that shows it. Wait for it to settle, once.
		if not toggleRetry then
			toggleRetry = true
			task.delay(0.3, function()
				toggleRetry = false
				A.toggleUI()
			end)
		end
		return
	end

	-- Decide from what is actually on screen, not from a flag that can drift out of
	-- step with it. A desynced `hidden` made this hide something already hidden,
	-- which reads exactly like "the shortcut does nothing". Now any state where the
	-- panel is not visible means the next press shows it.
	local show = hidden or not anyVisible()
	hidden = not show
	if DEBUG then
		print(string.format("[Aether] toggleUI show=%s visible=%s", tostring(show), tostring(anyVisible())))
	end
	sfx(show and "open" or "close")

	if show then
		-- Restore only what is still a legitimate target. A config menu's frame is
		-- built once and hidden, never destroyed, so a stale hiddenTarget would bring
		-- back the settings sheet with the main window still invisible behind it.
		local target = hiddenTarget
		local live = target and target.Parent and (target == window or (UI.active and UI.active.frame == target))
		if not live then
			target = window
			hiddenTarget = nil
		end
		local full = target.Size
		target.Size = UDim2.fromOffset(full.X.Offset * 0.8, full.Y.Offset * 0.8)
		target.GroupTransparency = 1
		target.Visible = true
		shadow.Visible = true
		tween(target, 0.8, { Size = full, GroupTransparency = 0 }, Enum.EasingStyle.Elastic)
		tween(shadow, 0.3, { ImageTransparency = shadowAlpha })
	else
		local target = UI.active and UI.active.frame or window
		hiddenTarget = target
		-- A TextBox that still holds focus makes UserInputService:GetFocusedTextBox()
		-- non-nil, and the dispatcher drops every key while that is true - including
		-- the one that would bring the panel back. Let go of it as we hide.
		local box = UserInputService:GetFocusedTextBox()
		if box then pcall(function() box:ReleaseFocus() end) end
		tween(target, 0.2, { GroupTransparency = 1 })
		tween(shadow, 0.2, { ImageTransparency = 1 })
		task.delay(0.2, function()
			if hidden then
				if target.Parent then target.Visible = false end
				shadow.Visible = false
			end
		end)
		local key = bindName("Toggle UI")
		notify("Aether hidden", key and ("press " .. key .. " to show") or "no key bound to show it again")
	end
end

closeBtn.MouseButton1Click:Connect(A.toggleUI)

-- search: filters rows by name, jumps to the first page that has a match --
-- A count sits in the right of the field, because "the page went blank" and
-- "nothing matched" look identical otherwise.
local searchHits = label({
	Text = "", TextColor3 = T.muted, TextSize = 10, RichText = false,
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.fromOffset(66, 14), TextXAlignment = Enum.TextXAlignment.Right,
	Parent = A.search,
})

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = searchBox.Text:lower()
	local firstPage
	local n = 0
	for _, e in ipairs(A.registry) do
		if e.row and e.row.Parent then
			local match = q == "" or e.name:lower():find(q, 1, true) ~= nil
			e.row.Visible = match
			if match then
				n += 1
				if q ~= "" and not firstPage then
					for name, page in pairs(A.pages) do
						if e.row:IsDescendantOf(page.scroll) then
							firstPage = name
							break
						end
					end
				end
			end
		end
	end
	if q == "" then
		searchHits.Text = ""
	else
		searchHits.Text = n == 0 and "no hit" or (n .. (n == 1 and " hit" or " hits"))
		searchHits.TextColor3 = n == 0 and T.bad or T.muted
	end
	if firstPage and A.activeTab ~= firstPage then
		local cur = A.pages[A.activeTab]
		local curHas = false
		if cur then
			for _, e in ipairs(A.registry) do
				if e.row.Visible and e.row:IsDescendantOf(cur.scroll) then curHas = true; break end
			end
		end
		if not curHas then A.selectPage(firstPage) end
	end
end)

-- Keyboard access to the search box: "/" or Ctrl+F focuses it, Escape empties
-- it and hands focus back. Both are skipped while any text box is focused, so
-- typing a slash into a value field still types a slash.
local searchConn = UserInputService.InputBegan:Connect(function(i, gp)
	if gp or i.UserInputType ~= Enum.UserInputType.Keyboard then return end
	local focused = UserInputService:GetFocusedTextBox()
	local kc = i.KeyCode
	if kc == Enum.KeyCode.Escape then
		if focused == searchBox then
			searchBox:ReleaseFocus()
			searchBox.Text = ""
		end
		return
	end
	if focused then return end
	local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if kc == Enum.KeyCode.Slash or (ctrl and kc == Enum.KeyCode.F) then
		if not anyVisible() then A.toggleUI() end
		searchBox:CaptureFocus()
	end
end)
A.onCleanup(function() searchConn:Disconnect() end)

-- unload ---------------------------------------------------------
-- core/env.lua registers A.unload before the first file runs (so a failed load can
-- roll back), which is what the settings page and _G.AetherUnload both use.

-- go -------------------------------------------------------------
A.selectPage("Character")
pcall(A.loadConfig)

window.Size = UDim2.fromOffset(A.W * 0.8, A.H * 0.8)
window.GroupTransparency = 1
tween(window, 0.8, { Size = UDim2.fromOffset(A.W, A.H), GroupTransparency = 0 }, Enum.EasingStyle.Elastic)

local key = bindName("Toggle UI")
notify("Aether loaded", key and ("press " .. key .. " to hide or show") or "ready", "good")

-- after the entrance settles, so the question is not competing with the animation
if A.tts then task.delay(0.7, A.tts.maybePrompt) end

A.stage("9 startup done")
