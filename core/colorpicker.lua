local A = ...

-- Colour picker --------------------------------------------------------------
-- A saturation/value square, a hue strip and a hex field, in place of a fixed
-- list of named swatches. Everything is built from primitives the rest of the UI
-- already uses - two UIGradient overlays over a computed base colour, and one
-- ColorSequence on the hue strip - so it costs no assets and cannot 404.
--
--   A.colorPicker(parent, name, defaultColor, onChanged, legacyNames)
--
-- legacyNames maps the old stored strings ("Blue") onto colours, so a config
-- written before this widget existed still loads instead of snapping to default.

local new, tween, corner, labelFn = A.new, A.tween, A.corner, A.label
local T, FONT = A.T, A.FONT
local UIS = A.UserInputService
local sfx = A.sfx

local function clamp01(n)
	if n < 0 then return 0 elseif n > 1 then return 1 end
	return n
end

local function hexOf(c)
	return string.format("#%02X%02X%02X",
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function rgbOf(c)
	return string.format("%d, %d, %d",
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function parseHex(text)
	local raw = tostring(text or ""):gsub("%s+", ""):gsub("^#", "")
	if #raw ~= 6 or raw:find("%X") then return nil end
	local ok, c = pcall(function() return Color3.fromHex(raw) end)
	if ok and c then return c end
	return nil
end

-- The 36px topbar sits inside the coordinate space the mouse is reported in but
-- outside the one GuiObjects live in, so pointer maths needs it subtracted.
local guiInset = 0
pcall(function()
	guiInset = game:GetService("GuiService"):GetGuiInset().Y
end)

local HUE_CYCLE = ColorSequence.new({
	ColorSequenceKeypoint.new(0.000, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1.000, Color3.fromRGB(255, 0, 0)),
})

function A.colorPicker(parent, name, defaultColor, onChanged, legacyNames)
	local row = A.rowBase(parent)
	labelFn({ Text = name, Font = FONT.med, TextSize = 12, Position = UDim2.fromOffset(11, 0), Name = name, Size = UDim2.new(1, -140, 1, 0), Parent = row })

	local swatch = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(18, 18), BackgroundColor3 = defaultColor, BorderSizePixel = 0, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 5) }) })
	new("UIStroke", { Color = T.stroke, Transparency = 0.2, Thickness = 1, Parent = swatch })

	local hexLabel = labelFn({
		Text = hexOf(defaultColor), TextColor3 = T.muted, TextSize = 11,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -34, 0.5, 0),
		Size = UDim2.fromOffset(70, 14), TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})

	-- panel -------------------------------------------------------
	local ROW_CLOSED, ROW_OPEN = 34, 200
	local PANEL_Y, SQUARE_H, HUE_H = 38, 96, 12

	local square = new("Frame", {
		Position = UDim2.fromOffset(9, PANEL_Y), Size = UDim2.new(1, -18, 0, SQUARE_H),
		BackgroundColor3 = Color3.fromHSV(0.6, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
		Visible = false, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }) })

	local wash = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = square,
	})
	new("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = wash,
	})

	local shade = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0, Parent = square,
	})
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = shade,
	})

	local cursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(13, 13),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = square,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	-- one stroke only: a second UIStroke on the same object never renders, so the
	-- ring is white with a soft dark edge baked into the same stroke
	new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = cursor })

	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = square })

	local hue = new("Frame", {
		Position = UDim2.fromOffset(9, PANEL_Y + SQUARE_H + 8), Size = UDim2.new(1, -18, 0, HUE_H),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("UIGradient", { Color = HUE_CYCLE, Parent = hue })

	local hCursor = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.6, 0, 0, PANEL_Y + SQUARE_H + 8 + HUE_H / 2),
		Size = UDim2.fromOffset(14, HUE_H + 8), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Visible = false, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.45, Parent = hCursor })

	local hueHit = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = hue })

	local hexBox = new("TextBox", {
		Text = hexOf(defaultColor), ClearTextOnFocus = false,
		Position = UDim2.fromOffset(9, PANEL_Y + SQUARE_H + 28), Size = UDim2.new(1, -110, 0, 26),
		Font = FONT.reg, TextSize = 11, TextColor3 = T.text, TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundColor3 = T.raised, BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Visible = false, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(0, 6) }), new("UIStroke", { Color = T.stroke, Transparency = 0.4, Thickness = 1 }) })
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), Parent = hexBox })

	local rgbLabel = labelFn({
		Text = rgbOf(defaultColor), TextColor3 = T.muted, TextSize = 10,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, PANEL_Y + SQUARE_H + 35),
		Size = UDim2.fromOffset(90, 14), TextXAlignment = Enum.TextXAlignment.Right, Visible = false, Parent = row,
	})

	-- state -------------------------------------------------------
	local h, s, v = Color3.toHSV(defaultColor)
	local current = defaultColor

	local function emit(apply)
		current = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = current
		hexLabel.Text = hexOf(current)
		rgbLabel.Text = rgbOf(current)
		square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.fromScale(s, 1 - v)
		hCursor.Position = UDim2.fromScale(h, 0.5)
		if apply == false then return end
		if onChanged then pcall(onChanged, current) end
		if A.touch then A.touch() end
	end

	local function setColor(c, silent)
		h, s, v = Color3.toHSV(c)
		hexBox.Text = hexOf(c)
		emit(not silent)
	end

	emit(false)

	-- dragging ----------------------------------------------------
	local function follow(target, onMove)
		local dragging = false
		local function apply()
			local abs, size = target.AbsolutePosition, target.AbsoluteSize
			local m = UIS:GetMouseLocation()
			local x = clamp01((m.X - abs.X) / math.max(size.X, 1))
			local y = clamp01(((m.Y - guiInset) - abs.Y) / math.max(size.Y, 1))
			onMove(x, y)
		end
		target.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				apply()
			end
		end)
		UIS.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				apply()
			end
		end)
		UIS.InputEnded:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				if dragging then sfx("tap") end
				dragging = false
			end
		end)
	end

	follow(hit, function(x, y)
		s = x
		v = 1 - y
		emit()
	end)

	follow(hueHit, function(x)
		h = x % 1
		emit()
	end)

	-- open / close ------------------------------------------------
	local open = false
	local function setOpen(next)
		open = next
		tween(row, 0.18, { Size = UDim2.new(1, 0, 0, open and ROW_OPEN or ROW_CLOSED) })
		square.Visible = open
		hue.Visible = open
		hCursor.Visible = open
		hexBox.Visible = open
		rgbLabel.Visible = open
		if open then sfx("hover") end
	end

	local toggleBtn = new("TextButton", {
		Text = "", BackgroundTransparency = 1,
		Size = UDim2.new(1, -110, 0, ROW_CLOSED), Parent = row,
	})
	toggleBtn.MouseButton1Click:Connect(function()
		setOpen(not open)
	end)

	-- typed hex ---------------------------------------------------
	local function commitHex()
		local c = parseHex(hexBox.Text)
		if not c then
			hexBox.Text = hexOf(current)
			return
		end
		if hexOf(c) == hexOf(current) then return end
		setColor(c)
	end
	hexBox.FocusLost:Connect(commitHex)

	-- config ------------------------------------------------------
	A.register(row, name, function(stored)
		if type(stored) ~= "string" then return end
		local c = (legacyNames and legacyNames[stored]) or parseHex(stored)
		if not c then return end
		-- silent so the config load is not treated as an edit, but the colour it
		-- names still has to be applied: that is the whole point of saving it
		setColor(c, true)
		if onChanged then pcall(onChanged, current) end
	end, function()
		return hexOf(current)
	end)

	return { row = row, get = function() return current end, set = setColor }
end
