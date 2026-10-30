local A = ...
local TweenService, T, FONT = A.TweenService, A.T, A.FONT

function A.new(class, props, children)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = o end
	if props and props.Parent then o.Parent = props.Parent end
	return o
end

A.ANIM = { on = true }
local ANIM = A.ANIM

function A.tween(o, t, props, style)
	local st = style or Enum.EasingStyle.Back
	for _, pv in pairs(props) do
		if typeof(pv) == "Color3" then st = Enum.EasingStyle.Quint end
	end
	if not ANIM.on and (st == Enum.EasingStyle.Back or st == Enum.EasingStyle.Elastic) then st = Enum.EasingStyle.Quint end
	local tw = TweenService:Create(o, TweenInfo.new(ANIM.on and t * 1.2 or t, st, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local new = A.new

function A.corner(o, r)
	new("UICorner", { CornerRadius = UDim.new(0, math.floor(r * 1.7 + 0.5)), Parent = o })
end

function A.stroke(o, c, t)
	return new("UIStroke", { Color = c or T.stroke, Thickness = 1, Transparency = t or 0.5, Parent = o })
end

function A.pad(o, n)
	new("UIPadding", {
		PaddingTop = UDim.new(0, n), PaddingBottom = UDim.new(0, n),
		PaddingLeft = UDim.new(0, n), PaddingRight = UDim.new(0, n), Parent = o,
	})
end

-- drawn "x" icon (font glyphs can render as boxes in some clients)
function A.drawX(parent, len, col)
	for i = 1, 2 do
		new("Frame", {
			Name = "xarm", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(len, 1.5), Rotation = i == 1 and 45 or -45,
			BackgroundColor3 = col or T.muted, BorderSizePixel = 0, Parent = parent,
		})
	end
end

function A.label(props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Font = FONT.reg, TextColor3 = T.text,
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true, Parent = props.Parent,
	})
	for k, v in pairs(props) do if k ~= "Parent" then l[k] = v end end
	return l
end

