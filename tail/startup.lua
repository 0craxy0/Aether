local A = ...
local tween, notify, sfx = A.tween, A.notify, A.sfx
local window, shadow, UI = A.window, A.shadow, A.UI
local closeBtn, searchBox = A.closeBtn, A.searchBox
local keybinds = A.keybinds

-- show / hide ----------------------------------------------------
local hidden = false
local hiddenTarget = nil

local function bindName(action)
	for k, n in pairs(keybinds) do
		if n == action then return k end
	end
end

function A.toggleUI()
	if UI.busy then return end
	hidden = not hidden
	sfx(hidden and "close" or "open")
	if hidden then
		local target = UI.active and UI.active.frame or window
		hiddenTarget = target
		tween(target, 0.2, { GroupTransparency = 1 })
		tween(shadow, 0.2, { ImageTransparency = 1 })
		task.delay(0.2, function()
			if hidden then
				target.Visible = false
				shadow.Visible = false
			end
		end)
		local key = bindName("Toggle UI")
		notify("Aether hidden", key and ("press " .. key .. " to show") or "no key bound to show it again")
	else
		local target = hiddenTarget or window
		local full = target.Size
		target.Size = UDim2.fromOffset(full.X.Offset * 0.8, full.Y.Offset * 0.8)
		target.GroupTransparency = 1
		target.Visible = true
		shadow.Visible = true
		tween(target, 0.8, { Size = full, GroupTransparency = 0 }, Enum.EasingStyle.Elastic)
		tween(shadow, 0.3, { ImageTransparency = 0.5 })
	end
end

closeBtn.MouseButton1Click:Connect(A.toggleUI)

-- search: filters rows by name, jumps to the first page that has a match --
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = searchBox.Text:lower()
	local firstPage
	for _, e in ipairs(A.registry) do
		if e.row and e.row.Parent then
			local match = q == "" or e.name:lower():find(q, 1, true) ~= nil
			e.row.Visible = match
			if match and q ~= "" and not firstPage then
				for name, page in pairs(A.pages) do
					if e.row:IsDescendantOf(page.scroll) then
						firstPage = name
						break
					end
				end
			end
		end
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
A.stage("9 startup done")
