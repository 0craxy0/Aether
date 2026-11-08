local A = ...

-- Help text ------------------------------------------------------------------
-- A "?" after the label of any row that is not self-explanatory, and a tooltip
-- the size of its own text when you put the pointer on it. Nothing is hidden
-- behind an icon: the mark sits where the label ends, so a row that has an
-- explanation looks like a row that has an explanation.
--
-- A.help("Row name", "what it does")  -- safe to call for a row that is not
-- present (a page that did not load), which is why the list below can mention
-- rows from every shelf.
--
-- The badge has to sit above the row's own hit area - toggles and buttons cover
-- themselves with a transparent TextButton - so it is created last, as a sibling,
-- with a higher ZIndex.

local T, FONT = A.T, A.FONT
local new = A.new
local TextService = game:GetService("TextService")

local TIP_W = 212

local layer = new("Frame", {
	Name = "HelpLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	Active = false, ZIndex = 900, Parent = A.screen,
})

local tip = new("Frame", {
	Name = "HelpTip", Visible = false, ZIndex = 902,
	BackgroundColor3 = T.panel, BackgroundTransparency = 0.02, BorderSizePixel = 0,
	AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(TIP_W, 0), Parent = layer,
}, {
	new("UICorner", { CornerRadius = UDim.new(0, 8) }),
	new("UIStroke", { Color = T.stroke, Transparency = 0.1, Thickness = 1 }),
	new("UIPadding", {
		PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8),
		PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
	}),
})

local tipText = new("TextLabel", {
	BackgroundTransparency = 1, Text = "", TextWrapped = true,
	Font = FONT.reg, TextSize = 11, TextColor3 = T.text,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = tip,
})

local hideAt = 0
local shown = false

local function hide()
	shown = false
	tip.Visible = false
end

local function place(anchor)
	local origin = layer.AbsolutePosition
	local pos = anchor.AbsolutePosition - origin
	local size = anchor.AbsoluteSize
	local tsz = tip.AbsoluteSize
	local vp = layer.AbsoluteSize

	local x = pos.X
	local y = pos.Y + size.Y + 6
	if x + tsz.X > vp.X - 8 then x = vp.X - tsz.X - 8 end
	if y + tsz.Y > vp.Y - 8 then y = pos.Y - tsz.Y - 6 end
	tip.Position = UDim2.fromOffset(math.max(8, x), math.max(8, y))
end

local function show(anchor, text)
	tipText.Text = text
	shown = true
	hideAt = math.huge -- only a MouseLeave ends it
	tip.Visible = true
	-- AutomaticSize lands a frame later than the text does, so the first fit is
	-- a guess and the second one is the truth
	pcall(place, anchor)
	task.defer(function()
		if shown then pcall(place, anchor) end
	end)
end

local function hideSoon()
	if not shown then return end
	hideAt = os.clock() + 0.12
end

task.spawn(function()
	while layer.Parent do
		task.wait(0.05)
		if shown and os.clock() > hideAt then hide() end
	end
end)

-- badge ----------------------------------------------------------------------
local function labelledRow(name)
	for _, e in ipairs(A.registry) do
		if e.name == name and e.row then
			local lbl = e.row:FindFirstChildWhichIsA("TextLabel", true)
			if lbl and lbl.Text ~= "" then return e.row, lbl end
		end
	end
	return nil
end

function A.help(name, text)
	local row, lbl = labelledRow(name)
	if not row or not text then return false end
	if row:FindFirstChild("helpBadge") then return true end

	local okSize, w = pcall(function()
		return TextService:GetTextSize(lbl.Text, lbl.TextSize, lbl.Font, Vector2.new(2000, 40)).X
	end)
	local textW = okSize and w or 0

	local badge = new("TextLabel", {
		Name = "helpBadge", Text = "?", Font = FONT.bold, TextSize = 10,
		TextColor3 = T.muted, BackgroundColor3 = T.stroke, BackgroundTransparency = 0.35,
		BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(13, 13),
		ZIndex = 10, Parent = row,
	}, { new("UICorner", { CornerRadius = UDim.new(1, 0) }) })

	-- Measured against the row's laid-out width, which is not necessarily known on
	-- the frame the row is built; the deferred pass fixes anything that landed at
	-- the left edge because the row was still 0 wide.
	local function placeBadge()
		if not badge.Parent then return end
		local rw = row.AbsoluteSize.X
		local x = (lbl.Position.X.Offset or 0) + textW + 7
		if rw > 100 then x = math.clamp(x, 0, rw - 70) end
		badge.Position = UDim2.new(0, math.max(0, x), 0.5, 0)
	end
	placeBadge()
	task.defer(placeBadge)

	badge.MouseEnter:Connect(function()
		badge.BackgroundColor3 = T.accent
		badge.BackgroundTransparency = 0.1
		badge.TextColor3 = T.text
		show(badge, text)
	end)
	badge.MouseLeave:Connect(function()
		badge.BackgroundColor3 = T.stroke
		badge.BackgroundTransparency = 0.35
		badge.TextColor3 = T.muted
		hideSoon()
	end)
	return true
end

-- which rows get one ---------------------------------------------------------
-- Only the ones you cannot guess from the name. Anything self-evident (Noclip,
-- Fullbright, WalkSpeed) looks the same as it always did.
local ENTRIES = {
	["Anchor position"] = "Freezes you where you stand, and stays frozen after a respawn instead of being forgotten on the reset.",
	["Anti-fling"] = "Another script spins you or throws you: the spin is cancelled and your speed is capped. Nothing legitimate moves a character that way.",
	["Anti-teleport"] = "Puts you back if something moves you more than a few studs in one frame. Off by default - it cannot tell a griefer from the game doing it on purpose, and everything in the hub that moves you is exempted.",
	["Anti-void"] = "Catches you when you fall out of the map and puts you back on the nearest floor you can stand on.",
	["Low graphics"] = "Stops particles, trails, beams, smoke, fire and sparkles, hides decals and textures, and zeroes the two lighting environment scales. Fog and shadows belong to the two rows above this one.",
	["Highlight range"] = "How far from the camera a part can be and still get a box drawn round it.",
	["Max highlighted"] = "Ceiling on how many objects are boxed at once. The nearest matches win, the rest are ignored until something nearer leaves range.",
	["Scale UI contents"] = "On: the panel's logical size stays put and everything inside is drawn larger or smaller as one. Off: the panel gains real space and elements keep their pixel sizes, so more fits rather than getting bigger.",
	["UI rescaling"] = "Shows the corner handles on the window. Turning it off hides them; the size you already picked is kept.",
	["Apply sliders on release"] = "Sliders only commit when you let go, instead of on every pixel of the drag. Turn it off for live tuning and expect a lot more callbacks.",
	["Rubber band edges"] = "The window springs back when you drag or throw it past the edge of the screen instead of leaving it there.",
	["Rubber band size"] = "How far past the edge the window is allowed to go before it pulls back.",
	["Throw physics"] = "Lets you fling the window; it keeps travelling after you let go and slows down with friction.",
	["Throw friction"] = "How quickly a thrown window comes to rest. Lower is slipperier.",
	["Bounciness"] = "How much of the window's momentum survives hitting an edge.",
	["Auto-execute on teleport"] = "Queues one line with your executor so the hub re-runs itself after you change server. It re-runs the same build, and a rollback pin is respected.",
	["Remember this device"] = "Writes the publish token to Aether/publish.dkey, tied to this account and device, so publishing unlocks without pasting it again. Plaintext on disk, and only after a publish succeeds.",
	["Roll back to rev"] = "Pins this client to an older build, by rev or commit. The pin survives a reload and is what the teleport queue re-runs; Return to latest clears it.",
	["Check every"] = "How often the update check polls version.json. The Worker is polled separately and is not affected.",
	["Chat commands"] = "Reads your own chat lines as commands. The game has already sent them by the time it reads them, so everyone in the server sees a command you type there.",
	["Liquid Glass (beta)"] = "Puts a blurred, tinted layer behind the panel and lets the window's background see through. Costs frame time; the strength rows below set how much.",
	["Parallax depth"] = "How far the panel's layers lag behind the window when you move or throw it. Zero makes them rigid.",
	["Cursor magnetism"] = "Controls near the pointer lean toward it a couple of pixels. Purely cosmetic, and it settles back when you leave.",
	["Entrance motion"] = "Pages slide in from the side you came from and their rows settle one after another. Turn it off if you change pages fast.",
	["Exaggerated animations"] = "Pushes the window's motion further than it needs to go - bigger overshoot, more bounce.",
	["Cooldown padding (s)"] = "Extra seconds added to every pad cooldown before retrying. Raise it if the server is stricter than the table says.",
}
for name, text in pairs(ENTRIES) do
	pcall(A.help, name, text)
end
